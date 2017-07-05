class CleanupBuildsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        CleanupBuildsJob.perform_later(prj.id.to_s) if prj.build_server && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      cleanup_builds(prj)
    }
  end

  private
  def cleanup_builds(prj)
    build_server = prj.build_server

    job_name_prefix = prj.config[:JENKINS_PROJECT][:BUILD]

    logger.info("Cleanup jobs for #{job_name_prefix} on #{build_server.named}")

    jobs = build_server.api_client.job.list("#{job_name_prefix}-")

    orphans = jobs.reject {|job_name|
      prj.branches.any? {|branch|
        job_name.end_with?(branch.flat_name)
      }
    }

    orphans.each {|job_name|
      build_server.api_client.job.delete(job_name)
    }

    logger.info("Pruned #{orphans.count} jobs: #{orphans}")
  end
end
