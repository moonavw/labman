class SyncReleasesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    Project.where(:id.in => project_ids).each {|prj|
      sync_releases(prj)
    }
  end

  private
  def sync_releases(prj)
    logger.info("Syncing releases for #{prj.named}")

    code_manager = prj.code_manager

    tag_regexp = /\Av\d+\.\d+\.\d+\z/

    resp = code_manager.api_client.tags(prj.config[:GITLAB_PROJECT])
    tags = resp.map(&:to_hash).select {|tag|
      tag_regexp.match?(tag['name'])
    }.sort {|x, y|
      Gem::Version.new(y['name'].sub('v', '')) <=> Gem::Version.new(x['name'].sub('v', ''))
    }

    resp = code_manager.api_client.milestones(prj.config[:GITLAB_PROJECT])
    releases = resp.map {|d|
      r = d.to_hash
      release = prj.releases.find_or_initialize_by(name: r['title'])
      release.uid = r['id']
      release.due_date = r['due_date'].to_date

      case r['state']
        when 'active'
          release.state = :to_do
        when 'closed'
          release.state = :done
        else
          # nothing
      end

      # move to in progress if possible
      release.work_in_progress

      last_tag, *_ = tags.select {|tag|
        tag['name'].start_with?("v#{release.name}.")
      }

      if last_tag.present?
        release.tag_name = last_tag['name']

        if release.branch.present?
          if release.branch.commit == last_tag['commit']['id']
            release.check = :updated
          else
            release.check = :outdated
          end
        end
      else
        release.tag_name = nil
        release.check = :outdated if release.state.in_progress?
      end

      if release.save
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
