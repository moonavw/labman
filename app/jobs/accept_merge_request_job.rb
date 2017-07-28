class AcceptMergeRequestJob < ApplicationJob
  queue_as :default

  def perform(*merge_request_ids)
    MergeRequest.with_state(:approved).where(:id.in => merge_request_ids).each {|merge_request|
      accept_merge_request(merge_request)
    }
  end

  private
  def accept_merge_request(merge_request)
    logger.info("Accepting #{merge_request.named}")

    prj = merge_request.project
    build_server = prj.build_server

    job_name = prj.config[:JENKINS_PROJECT][:ACCEPT_MERGE_REQUEST]

    unless build_server.api_client.job.exists?(job_name)
      logger.error("Not found #{job_name} on #{build_server.named}")
      return
    end

    job_params = {
        SOURCE_BRANCH: merge_request.source_branch.name,
        TARGET_BRANCH: merge_request.target_branch.name
    }

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
      logger.error("Unsuccessful accepting #{merge_request.named}, due to #{job_name}: #{status}")
      return
    end

    merge_request.update!(state: :accepted)
    merge_request.source_branch.destroy
    merge_request.target_branch.release.update!(check: :outdated) if merge_request.target_branch.release.present?

    logger.info("Accepted #{merge_request.named}")

    if merge_request.issue.present?
      target_transitions = prj.config[:JIRA_ISSUE_TRANSITIONS][:ACCEPT_MERGE_REQUEST]
      TransitIssueJob.perform_later(target_transitions, merge_request.issue.id.to_s)

      # get release from target branch
      if merge_request.target_branch.release.present?
        release = merge_request.target_branch.release
      elsif merge_request.target_branch.protected? && merge_request.target_branch.category.nil?
        release = prj.releases.with_state(:in_progress).where(tag_name: nil).first
      end

      VersionIssueJob.perform_later(release.name, merge_request.issue.id.to_s) if release.present?
    end

  end
end
