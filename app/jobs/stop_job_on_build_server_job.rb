class StopJobOnBuildServerJob < ApplicationJob
  queue_as :default

  def perform(project_id, *job_names)
    prj = Project.find(project_id)

    build_server = prj.build_server

    job_names.each {|job_name|
      build_server.api_client.job.stop_build(job_name)
      logger.info("Stopped job: #{job_name} on #{build_server.named}")
    }
  end
end
