class SyncMergeRequestsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncMergeRequestsJob.perform_later(prj.id.to_s) if prj.code_manager && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_merge_requests(prj)
    }
  end

  private
  def sync_merge_requests(prj)
    logger.info("Syncing merge requests for #{prj.named}")

    code_manager = prj.code_manager

    resp = code_manager.api_client.merge_requests(prj.config[:GITLAB_PROJECT], {state: :opened, per_page: 50})
    merge_requests = resp.map {|d|
      b = d.to_hash

      source_branch = prj.branches.find_by(name: b['source_branch'])
      merge_request = source_branch.merge_requests.find_or_initialize_by(name: "!#{b['iid']}", uid: b['id'], url: b['web_url'])

      merge_request.release = prj.releases.find_by(name: b['milestone']['title']) if b['milestone']

      merge_request.target_branch_name = b['target_branch']

      merge_request.issue = prj.issues.select {|issue|
        b['title'].include?(issue.name)
      }.first

      if !b['work_in_progress'] && b['merge_status'] == 'can_be_merged' && b['upvotes'] > b['downvotes']
        # TODO: merge_when_build_succeeds
        merge_request.state = :reviewed
      else
        merge_request.state = :opened
      end

      if merge_request.save
        logger.info("Synced #{merge_request.named}")
      else
        logger.error("Failed sync #{merge_request.named}")
        logger.error(merge_request.errors.messages)
      end

      merge_request
    }

    logger.info("Synced #{merge_requests.count} merge requests")

    synced_ids = merge_requests.map(&:id)
    orphans = prj.merge_requests.where(:id.nin => synced_ids)
    sync_orphaned_merge_requests(prj, orphans) if orphans.any?
  end

  def sync_orphaned_merge_requests(prj, orphans)
    logger.info("Syncing orphaned #{orphans.count} merge requests for #{prj.named}")

    code_manager = prj.code_manager

    orphans.each {|merge_request|
      resp = code_manager.api_client.merge_request(prj.config[:GITLAB_PROJECT], merge_request.uid)
      b = resp.to_hash

      if b['state'] == 'closed'
        merge_request.destroy
        next
      end

      if b['state'] == 'merged'
        if b['milestone']
          merge_request.release = prj.releases.find_by(name: b['milestone']['title'])
          if merge_request.release.state.done?
            merge_request.destroy
            next
          end
        end

        merge_request.target_branch_name = b['target_branch']

        merge_request.issue = prj.issues.select {|issue|
          b['title'].include?(issue.name)
        }.first

        merge_request.state = :accepted

        if merge_request.save
          logger.info("Synced #{merge_request.named}")
        else
          logger.error("Failed sync #{merge_request.named}")
          logger.error(merge_request.errors.messages)
        end
      end
    }

    synced = orphans.count(&:persisted?)
    logger.info("Synced orphaned #{synced} merge requests")
    logger.info("Pruned orphaned #{orphans.count - synced} merge requests")
  end
end
