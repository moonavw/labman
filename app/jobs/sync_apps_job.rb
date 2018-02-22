class SyncAppsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    Project.where(:id.in => project_ids).each {|prj|
      sync_apps(prj)
    }
  end

  private
  def sync_apps(prj)
    logger.info("Syncing apps for #{prj.named}")

    app_platform = prj.app_platform

    resp = app_platform.api_client.app.list.select {|a|
      a['name'].start_with? prj.config[:HEROKU_PROJECT]
    }
    apps = resp.map {|a|
      app = prj.apps.find_or_initialize_by(name: a['name'])
      app.uid = a['id']
      app.url = a['web_url']
      app.config = app_platform.api_client.config_var.info_for_app(app.name)

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
