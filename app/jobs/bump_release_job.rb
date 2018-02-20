class BumpReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(check: nil, :id.in => release_ids).each {|release|
      bump_release(release)
    }
  end

  private
  def bump_release(release)
    logger.info("Bumping #{release.named}")

    prj = release.project
    build_server = prj.build_server

    if release.branch.present?
      job_name = prj.config[:JENKINS_PROJECT][:RC_PATCH]
      job_params = {
          RC_VERSION: release.name
      }
    else
      job_name = prj.config[:JENKINS_PROJECT][:RC]
      job_params = {
          BUMP_VERSION: "#{release.name}.0"
      }
    end

    unless build_server.api_client.job.exists?(job_name)
      logger.error("Not found #{job_name} on #{build_server.named}")
      return
    end

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
    end while status == 'running'

    unless status == 'success'
      logger.error("Unsuccessful bumping #{release.named}, due to #{job_name}: #{status}")
      return
    end

    # update locals instead of SyncBranchesJob.perform_now(prj.id.to_s)
    prj.branches.create!(name: release.branch_name, protected: true) unless release.branch.present?

    unless release.branch.protected?
      logger.info("Protect #{release.branch_name}")
      prj.code_manager.api_client.protect_branch(prj.config[:GITLAB_PROJECT], release.branch_name)
    end

    # update locals instead of SyncReleasesJob.perform_now(prj.id.to_s) ; release.reload
    resp = build_server.api_client.job.get_build_details(job_name, job_build_number)
    tag_name = resp['displayName'].chomp
    release.update!(tag_name: tag_name, check: :updated)

    logger.info("Bumped #{release.named} -> #{release.tag_name}")

    release.rebuild
  end
end
