class SyncAppsJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncAppsJob.perform_later(prj.id.to_s) if prj.platform && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_apps(prj)
      sync_pipelines(prj)
    }
  end

  private
  def sync_apps(prj)
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

      app.state = :idle unless app.locked_build.present?

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

  def sync_pipelines(prj)
    logger.info("Syncing pipelines for project: #{prj.name}")

    api_client = prj.platform.api_client

    resp = api_client.pipeline.list.select {|pl|
      pl['name'].start_with? prj.config[:HEROKU_PROJECT]
    }
    pipelines = resp.map {|pl|
      pipeline = prj.pipelines.find_or_initialize_by(name: pl['name'])
      pipeline.uid = pl['id']

      if pipeline.save
        logger.info("Synced pipeline: #{pipeline.name}")

        # coupling apps to pipeline
        couplings = api_client.pipeline_coupling.list_by_pipeline(pipeline.uid)
        apps = couplings.map {|c|
          app = prj.apps.find_by(uid: c['app']['id'])
          app.stage = c['stage'].to_sym
          app.pipeline = pipeline

          if app.save
            logger.info("Coupled app: #{app.name}")
          else
            logger.error("Failed couple app: #{app.name}")
            logger.error(app.errors.messages)
          end

          app
        }

        logger.info("Coupled #{apps.count} apps")

        coupled_ids = apps.map(&:id)
        decouples = pipeline.apps.where(:id.nin => coupled_ids).to_a
        pipeline.apps -= decouples

        logger.warn("Decoupled #{decouples.count} apps")

      else
        logger.error("Failed sync pipeline: #{pipeline.name}")
        logger.error(pipeline.errors.messages)
      end

      pipeline
    }

    logger.info("Synced #{pipelines.count} pipelines")

    synced_ids = pipelines.map(&:id)
    orphans = prj.pipelines.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} pipelines")
  end
end
