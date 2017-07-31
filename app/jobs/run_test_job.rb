class RunTestJob < ApplicationJob
  queue_as :default

  def perform(*test_ids)
    Test.with_state(:pending).where(:id.in => test_ids).each {|test|
      queue_test(test)
    }
  end

  private
  def queue_test(test)
    logger.info("Run #{test.named}")

    prj = test.branch.project
    build_server = prj.build_server

    job_name_prefix = prj.config[:JENKINS_PROJECT][:TEST]
    job_name = "#{job_name_prefix}-#{test.branch.flat_name}"
    test.url = "http://#{build_server.config[:server_ip]}:#{build_server.config[:server_port]}/job/#{job_name}"

    unless build_server.api_client.job.exists?(job_name)
      logger.info("Creating job: #{job_name} on #{build_server.named}")

      unless build_server.api_client.job.exists?(job_name_prefix)
        logger.error("Not found #{job_name_prefix} on #{build_server.named}")
        return
      end

      resp = build_server.api_client.job.copy(job_name_prefix, job_name)
      unless %w(201 302).include?(resp)
        logger.error("Unsuccessful Creating job, #{build_server.named} response: #{resp}")
        return
      end

      # need disable then enable to make the job buildable
      build_server.api_client.job.disable(job_name)
      build_server.api_client.job.enable(job_name)
    end

    job_params = {
        NAME: test.name,
        BRANCH: test.branch.name,
        APP_URL: (test.branch.build.app.url if test.branch.build.present?)
    }

    job_params.merge!(test.final_config.symbolize_keys)
    logger.info("Queueing job: #{job_name}, with params: #{job_params}")

    previous_job_build_number = build_server.api_client.job.get_current_build_number(job_name)

    resp = build_server.api_client.job.build(job_name, job_params)

    unless resp == '201'
      logger.error("Unsuccessful queue job, #{build_server.named} response: #{resp}")
      return
    end

    logger.info("Queued job: #{job_name}, wait a few sec to check status")

    begin
      sleep 5
      job_build_number = build_server.api_client.job.get_current_build_number(job_name)
    end while job_build_number == previous_job_build_number

    begin
      sleep 5
      status = build_server.api_client.job.status(job_name)
      logger.info("Job #{job_name} status: #{status}")

      case status
        when 'success', 'failure'
          test.result = status.to_sym
          test.state = :completed
        when 'running', 'aborted'
          test.state = status.to_sym
        else
          logger.error('Unknown status')
          test.state = :pending
      end
      test.save!
    end while test.state.running?

    logger.info("Finished Run #{test.named} -> #{test.status}")
  end
end
