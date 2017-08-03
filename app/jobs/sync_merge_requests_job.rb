class SyncMergeRequestsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
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

      merge_request = prj.merge_requests.find_or_initialize_by(name: "!#{b['iid']}", uid: b['id'], url: b['web_url'])
      merge_request.source_branch = prj.branches.where(name: b['source_branch']).first
      merge_request.target_branch = prj.branches.where(name: b['target_branch']).first

      merge_request.release = prj.releases.find_by(name: b['milestone']['title']) if b['milestone']

      merge_request.issue = prj.issues.select {|issue|
        b['title'].include?(issue.name)
      }.first

      if !b['work_in_progress'] && b['merge_status'] == 'can_be_merged' && (b['upvotes'] - b['downvotes']) >= prj.config[:MERGE_REQUEST][:APPROVAL]
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

    unaccepted_orphans = orphans.without_state(:accepted).destroy_all

    logger.warn("Pruned #{unaccepted_orphans} orphaned unaccepted merge requests")

    accepted_orphans = orphans.with_state(:accepted).select{|mr|
      mr.target_branch.nil? || mr.issue.nil?
    }.each(&:destroy).count

    logger.warn("Pruned #{accepted_orphans} orphaned accepted merge requests")
  end
end
