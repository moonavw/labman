class SyncBranchesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    Project.where(:id.in => project_ids).each {|prj|
      sync_branches(prj)
    }
  end

  private
  def sync_branches(prj)
    logger.info("Syncing branches for #{prj.named}")

    code_manager = prj.code_manager

    resp = code_manager.api_client.branches(prj.config[:GITLAB_PROJECT], { per_page: 100 })
    branches = resp.map {|d|
      b = d.to_hash
      branch = prj.branches.find_or_initialize_by(name: b['name'])
      branch.protected = b['protected']
      branch.commit = b['commit']['id']

      branch.build.rerun if branch.commit_changed? && branch.build.present? && branch.build.branch.release.nil?

      if branch.save
        logger.info("Synced #{branch.named}")
      else
        logger.error("Failed sync #{branch.named}")
        logger.error(branch.errors.messages)
      end

      branch
    }

    logger.info("Synced #{branches.count} branches")

    synced_ids = branches.map(&:id)
    orphans = prj.branches.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} branches")
  end
end
