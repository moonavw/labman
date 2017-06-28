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

    job_name_suffix = 'mr-accept'
    job_params = {
        sourceBranch: merge_request.source_branch.name,
        targetBranch: merge_request.target_branch_name
    }


    prj = merge_request.project

    api_client = prj.build_server.api_client

    jobs = api_client.job.list(prj.config[:JENKINS_PROJECT])

    logger.info("Found jobs on #{prj.build_server.named}: #{jobs}")

    job_name = jobs.select {|j|
      j.end_with?(job_name_suffix)
    }.first

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
    end while status == 'running'

    unless status == 'success'
      logger.error("Unsuccessful accepting #{merge_request.named}, due to #{job_name}: #{status}")
      return
    end

    merge_request.update(state: :accepted)

    logger.info("Accepted #{merge_request.named}")
  end
end
