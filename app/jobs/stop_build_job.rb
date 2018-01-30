class StopBuildJob < ApplicationJob
  queue_as :default

  def perform(*build_ids)
    Build.with_state(:aborted).where(:id.in => build_ids).each {|build|
      stop_build(build)
    }
  end

  private
  def stop_build(build)
    logger.info("Stopping #{build.named}")

    prj = build.branch.project
    build_server = prj.build_server

    job_name = build.job_name

    current_build_number = build_server.api_client.job.get_current_build_number(job_name)
    resp = build_server.api_client.job.stop_build(job_name)
    unless resp == '302'
      logger.error("Unsuccessful stop job, #{build_server.named} response: #{resp}")
      return
    end

    logger.info("Stopped #{build.named}, build number: #{current_build_number}")
  end
end
