class SyncAppsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncAppsJob.perform_later(prj.id.to_s) if prj.app_platform && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_apps(prj)
    }

    SyncPipelinesJob.perform_later(*project_ids)
  end

  private
  def sync_apps(prj)
    logger.info("Syncing apps for #{prj.named}")

    api_client = prj.app_platform.api_client

    resp = api_client.app.list.select {|a|
      a['name'].start_with? prj.config[:HEROKU_PROJECT]
    }
    apps = resp.map {|a|
      app = prj.apps.find_or_initialize_by(name: a['name'])
      app.uid = a['id']
      app.url = a['web_url']
      app.config = api_client.config_var.info_for_app(app.name)

      app.state = :opened unless app.locked_build

      if app.save
        logger.info("Synced #{app.named}")
      else
        logger.error("Failed sync #{app.named}")
        logger.error(app.errors.messages)
      end

      app
    }

    logger.info("Synced #{apps.count} apps")

    synced_ids = apps.map(&:id)
    orphans = prj.apps.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} apps")

    SyncAppVersionJob.perform_later(*synced_ids.map(&:to_s))
  end
end
