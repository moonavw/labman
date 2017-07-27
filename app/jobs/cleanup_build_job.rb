class CleanupBuildJob < ApplicationJob
  queue_as :default

  def perform(project_id, *branch_flat_names)
    prj = Project.find(project_id)

    build_server = prj.build_server

    job_name_prefix = prj.config[:JENKINS_PROJECT][:BUILD]

    logger.info("Cleanup jobs for #{job_name_prefix}-#{branch_flat_names} on #{build_server.named}")

    jobs = build_server.api_client.job.list("#{job_name_prefix}-")

    orphans = jobs.select {|job_name|
      branch_flat_names.any? {|branch_flat_name|
        job_name == "#{job_name_prefix}-#{branch_flat_name}"
      }
    }

    orphans.each {|job_name|
      build_server.api_client.job.delete(job_name)
    }

    logger.info("Pruned #{orphans.count} jobs: #{orphans}")
  end
end
