class SyncReleasesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncReleasesJob.perform_later(prj.id.to_s) if prj.code_manager && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_releases(prj)
    }
  end

  private
  def sync_releases(prj)
    logger.info("Syncing releases for #{prj.named}")

    api_client = prj.code_manager.api_client

    resp = api_client.tags(prj.config[:GITLAB_PROJECT])
    tags = resp.map {|d|
      t = d.to_hash
      t['name'].sub('v', '')
    }.reject {|tag_name|
      tag_name.include?('-')
    }.sort {|x, y|
      Gem::Version.new(y) <=> Gem::Version.new(x)
    }

    resp = api_client.milestones(prj.config[:GITLAB_PROJECT])
    releases = resp.map {|d|
      r = d.to_hash
      release = prj.releases.find_or_initialize_by(name: r['title'])
      release.due_date = r['due_date'].to_date

      case r['state']
        when 'active'
          release.state = :to_do
        when 'closed'
          release.state = :done
        else
          # nothing
      end

      release.tag_name = tags.select {|tag_name|
        tag_name.start_with?("#{release.name}.")
      }.first

      if release.save
        release.work_in_progress
        logger.info("Synced #{release.named}")
      else
        logger.error("Failed sync #{release.named}")
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
