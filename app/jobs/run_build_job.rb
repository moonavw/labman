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

    job_name_prefix = prj.config[:JENKINS_PROJECT][:BUILD]
    job_name = "#{job_name_prefix}-#{build.branch.flat_name}"
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

    if build.config.present? && !build.config.empty?
      config_keys = build.config.keys & build.app.config.keys

      app_config = build.config.select {|k, v| config_keys.include?(k)}
      logger.info("#{build.named} requires app config: #{app_config}")
    end

    job_params.merge!(build.final_config.symbolize_keys)
    # get next version from releases
    next_release = Release.without_state(:done).where(tag_name: nil).first
    job_params.merge!({NEXT_VERSION: "#{next_release.name}.0"}) if next_release.present?

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

    return unless build.status == :success

    if app_config.present? && !app_config.empty?
      logger.info("Updating #{build.app.named} config: #{app_config}")
      app_platform = prj.app_platform
      app_platform.api_client.config_var.update(build.app.name, app_config)
      logger.info("Updated #{build.app.named} config: #{app_config}")

      # update locals instead of SyncAppConfigJob.perform_later(build.app.id.to_s)
      build.app.config.merge!(app_config)
      build.app.save!
    end

    # update locals instead of SyncAppVersionJob.perform_later(build.app.id.to_s)
    resp = build_server.api_client.job.get_build_details(job_name, job_build_number)
    build.app.version_name = resp['displayName'].chomp.sub('v', '')
    build.app.save!

    # for rc build
    if build.branch.release.present?
      build.app.promote

      target_transitions = prj.config[:JIRA_ISSUE_TRANSITIONS][:BUILD_RELEASE]
      issue_ids = build.branch.release.issues.map(&:id)

      TransitIssueJob.perform_later(target_transitions, *issue_ids.map(&:to_s))
    end
  end
end
