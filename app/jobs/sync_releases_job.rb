class SyncReleasesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncReleasesJob.perform_later(prj.id.to_s)
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_releases(prj)
    }
  end

  private
  def sync_releases(prj)
    logger.info("Syncing releases for project: #{prj.name}")

    api_client = prj.code_manager.api_client

    resp = api_client.milestones(prj.config[:GITLAB_PROJECT])
    releases = resp.map {|d|
      r = d.to_hash
      release = prj.releases.find_or_initialize_by(name: r['title'])
      release.date = r['due_date'].to_date

      case r['state']
        when 'active'
          release.state = :to_do
        when 'closed'
          release.state = :done
        else
          # nothing
      end

      release.state = :in_progress if release.state.to_do? && release.issues.any?

      if release.save
        logger.info("Synced release: #{release.name}")
      else
        logger.error("Failed sync release: #{release.name}")
        logger.error(release.errors.messages)
      end

      release
    }

    logger.info("Synced #{releases.count} releases")

    synced_ids = releases.map(&:id)
    orphans = prj.releases.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} releases")
  end
end
