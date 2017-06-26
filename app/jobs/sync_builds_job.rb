class SyncBuildsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncBuildsJob.perform_later(prj.id.to_s)
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      prj.builds.with_state(:pending).each {|b|
        RunBuildJob.perform_later(b.id.to_s)
      }
    }
  end
end
