class RunBuildJob < ApplicationJob
  queue_as :default

  def perform(*build_ids)
    Build.with_state(:pending).where(:id.in => build_ids).each {|build|
      queue_build(build)
    }
  end

  def queue_build(build)
    logger.info("Run #{build.named}")

    prj = build.branch.project

    api_client = prj.build_server.api_client

    jobs = api_client.job.list(prj.config[:JENKINS_PROJECT])

    logger.info("Found jobs on #{prj.build_server.named}: #{jobs}")

    job_name = jobs.select {|j|
      j.end_with?('build') || j.end_with?('deploy')
    }.first

    job_params = {
        name: build.name,
        branch: build.branch.name,
        app: build.app.name
    }

    job_params.merge!(build.config.symbolize_keys) if build.config

    logger.info("Queueing job: #{job_name}, with params: #{job_params}")

    previous_job_build_number = api_client.job.get_current_build_number(job_name)

    resp = api_client.job.build(job_name, job_params)

    unless resp == '201'
      logger.error("Unsuccessful queue job, #{prj.build_server.named} response: #{resp}")
      return
    end

    logger.info("Queued job: #{job_name}, wait a few sec to check status")

    begin
      sleep 5
      job_build_number = api_client.job.get_current_build_number(job_name)
    end while job_build_number == previous_job_build_number

    begin
      sleep 5
      status = api_client.job.status(job_name)
      logger.info("Job #{job_name} status: #{status}")

      case status
        when 'success', 'failure'
          build.result = status.to_sym
          build.state = :completed
        when 'running', 'aborted'
          build.state = status.to_sym
        else
          logger.error('Unknown status')
          build.state = :pending
      end
      build.save!
    end while build.state.running?

    logger.info("Finished Run #{build.named} -> #{build.status}")

    SyncAppVersionJob.perform_later(build.app.id.to_s)
  end
end
