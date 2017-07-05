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

    code_manager = prj.code_manager

    resp = code_manager.api_client.tags(prj.config[:GITLAB_PROJECT])
    tags = resp.map(&:to_hash).reject {|tag|
      tag['name'].include?('-')
    }.sort {|x, y|
      Gem::Version.new(y['name'].sub('v', '')) <=> Gem::Version.new(x['name'].sub('v', ''))
    }

    resp = code_manager.api_client.milestones(prj.config[:GITLAB_PROJECT])
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

      latest_tag = tags.select {|tag|
        tag['name'].start_with?("v#{release.name}.")
      }.first

      if latest_tag
        release.tag_name = latest_tag['name']

        if release.branch
          commits = code_manager.api_client.commits(prj.config[:GITLAB_PROJECT], {ref_name: release.branch.name})
          latest_commit = commits.first
          if latest_commit
            c = latest_commit.to_hash
            if c['id'] == latest_tag['commit']['id']
              release.check = :updated
            else
              release.check = :outdated
            end
          end
        end
      else
        release.tag_name = nil
        release.check = :outdated unless release.state.done?
      end

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
