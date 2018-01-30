class RunBuildJob < ApplicationJob
  queue_as :default

  def perform(*build_ids)
    Build.with_state(:pending).where(:id.in => build_ids).each {|build|
      queue_build(build)
    }
  end

  private
  def queue_build(build)
    logger.info("Run #{build.named}")

    prj = build.branch.project
    build_server = prj.build_server

    job_name_prefix = build.job_name_prefix
    job_name = build.job_name
    build.url = "http://#{build_server.config[:server_ip]}:#{build_server.config[:server_port]}/job/#{job_name}"

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
        NAME: build.name,
        BRANCH: build.branch.name,
        APP: build.app.name
    }

    job_params.merge!(build.final_config.symbolize_keys)
    # get next version from releases
    next_release = Release.without_state(:done).where(tag_name: nil).first
    job_params.merge!({NEXT_VERSION: "#{next_release.name}.0"}) if next_release.present?

    logger.info("Queueing job: #{job_name}, with params: #{job_params}")

    previous_build_number = build_server.api_client.job.get_current_build_number(job_name)

    resp = build_server.api_client.job.build(job_name, job_params)

    unless resp == '201'
      logger.error("Unsuccessful queue job, #{build_server.named} response: #{resp}")
      return
    end

    logger.info("Queued job: #{job_name}, checking build number")

    begin
      sleep 5
      current_build_number = build_server.api_client.job.get_current_build_number(job_name)
    end while current_build_number == previous_build_number

    build.state = :running
    build.save!
    logger.info("Stared job: #{job_name}, build number: #{current_build_number}")
  end
end
