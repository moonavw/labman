class SyncAppVersionJob < ApplicationJob
  queue_as :default

  def perform(*app_ids)
    App.where(:id.in => app_ids).each {|app|
      sync_app_version(app)
    }
  end

  private
  def sync_app_version(app)
    prj = app.project
    config = prj.config[:APP][:CONFIG].merge(app.config)

    app_version_api = app.url.chomp('/') + prj.config[:APP][:VERSION_API] % config.symbolize_keys
    logger.info("Fetching #{app.named} version: #{app_version_api}")

    begin
      r = RestClient.get(app_version_api)
      version_data = JSON.parse(r)
      version_name = version_data['version']

      logger.info("Fetched #{app.named} version: #{version_name}")

      app.update!(version_name: version_name)
    rescue RestClient::ExceptionWithResponse => e
      logger.error("Failed fetching #{app.named} version")
      logger.error(e.response)
    end

  end
end
