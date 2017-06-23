class SyncBranchesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncBranchesJob.perform_later(prj.id.to_s) if prj.code_manager && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_branches(prj)
    }
  end

  private
  def sync_branches(prj)
    logger.info("Syncing branches for project: #{prj.name}")

    api_client = prj.code_manager.api_client

    resp = api_client.branches(prj.config[:GITLAB_PROJECT])
    branches = resp.map {|d|
      b = d.to_hash
      branch = prj.branches.find_or_initialize_by(name: b['name'])

      if branch.save
        logger.info("Synced branch: #{branch.name}")
      else
        logger.error("Failed sync branch: #{branch.name}")
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
