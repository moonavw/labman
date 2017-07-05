class SyncAppConfigJob < ApplicationJob
  queue_as :default

  def perform(*app_ids)
    App.where(:id.in => app_ids).each {|app|
      sync_app_config(app)
    }
  end

  private
  def sync_app_config(app)
    logger.info("Syncing app config for #{app.named}")

    prj = app.project
    app_platform = prj.app_platform

    app.config = app_platform.api_client.config_var.info_for_app(app.name)

    if app.save
      logger.info("Synced app config for #{app.named}")
    else
      logger.error("Failed sync app config for #{app.named}")
      logger.error(app.errors.messages)
    end
  end
end
