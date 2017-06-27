class BumpReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(:id.in => release_ids).each {|release|
      bump_release(release)
    }
  end

  def bump_release(release)
    logger.info("Bumping #{release.named}")

    if release.branch
      job_name_suffix = 'rc-patch'
      job_params = {
          RC_VERSION: release.name
      }
    else
      job_name_suffix = 'rc'
      job_params = {}
    end

    prj = release.project

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
      logger.error("Unsuccessful bumping #{release.named}, due to #{job_name}: #{status}")
      return
    end

    SyncReleasesJob.perform_now(prj.id.to_s)
    logger.info("Bumped #{release.named} -> #{release.tag_name}")

    BuildReleaseJob.perform_later(release.id.to_s)
  end
end
