class SyncAppsJob < ApplicationJob
  queue_as :default

  def perform(project_id)
    prj = Project.find(project_id)

    logger.info("Syncing apps for project: #{prj.name}")

    api_client = prj.platform.api_client

    resp = api_client.app.list.select {|a|
      a['name'].start_with? prj.config[:HEROKU_PROJECT]
    }
    apps = resp.map {|a|
      app = prj.apps.find_or_initialize_by(name: a['name'])
      app.uid = a['id']
      app.url = a['web_url']
      app.config = api_client.config_var.info_for_app(app.name)

      if app.save
        logger.info("Synced app: #{app.name}")
      else
        logger.error("Failed sync app: #{app.name}")
        logger.error(app.errors.messages)
      end

      app
    }

    logger.info("Synced #{apps.count} apps")

    synced_ids = apps.map(&:id)
    orphans = prj.apps.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} apps")
  end
end
