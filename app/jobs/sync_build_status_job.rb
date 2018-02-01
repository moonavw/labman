class SyncBuildStatusJob < ApplicationJob
  queue_as :default

  def perform(*build_ids)
    Build.where(:id.in => build_ids).each {|build|
      sync_build_status(build)
    }
  end

  private
  def sync_build_status(build)
    logger.info("Syncing #{build.named}")

    prj = build.project
    build_server = prj.build_server

    job_name = build.job_name

    return unless build_server.api_client.job.exists?(job_name)

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

    logger.info("Synced #{build.named} -> #{build.status}")

    return unless build.status == :success

    # update locals instead of SyncAppVersionJob.perform_later(build.app.id.to_s)
    current_build_number = build_server.api_client.job.get_current_build_number(job_name)
    resp = build_server.api_client.job.get_build_details(job_name, current_build_number)
    build.app.version_name = resp['displayName'].chomp.sub('v', '')
    build.app.save!

    if build.config.present? && !build.config.empty?
      config_keys = build.config.keys & build.app.config.keys

      app_config = build.config.select {|k, v| config_keys.include?(k)}
      logger.info("#{build.named} requires app config: #{app_config}")

      unless app_config.empty?
        logger.info("Updating #{build.app.named} config: #{app_config}")
        app_platform = prj.app_platform
        app_platform.api_client.config_var.update(build.app.name, app_config)
        logger.info("Updated #{build.app.named} config: #{app_config}")

        # update locals instead of SyncAppsJob.perform_later(build.app.id.to_s)
        build.app.config.merge!(app_config)
        build.app.save!
      end
    end

    # for rc build
    if build.branch.release.present?
      build.app.promote

      target_transitions = prj.config[:JIRA_ISSUE_TRANSITIONS][:BUILD_RELEASE]
      issue_ids = build.branch.release.issues.map(&:id)

      TransitIssueJob.perform_later(target_transitions, *issue_ids.map(&:to_s))
    end
  end
end
