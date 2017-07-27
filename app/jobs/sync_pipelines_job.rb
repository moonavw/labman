class SyncPipelinesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    Project.where(:id.in => project_ids).each {|prj|
      sync_pipelines(prj)
    }
  end

  private
  def sync_pipelines(prj)
    logger.info("Syncing pipelines for #{prj.named}")

    app_platform = prj.app_platform

    resp = app_platform.api_client.pipeline.list.select {|pl|
      pl['name'].start_with? prj.config[:HEROKU_PROJECT]
    }
    pipelines = resp.map {|pl|
      pipeline = prj.pipelines.find_or_initialize_by(name: pl['name'])
      pipeline.uid = pl['id']

      if pipeline.save
        logger.info("Synced #{pipeline.named}")

        # coupling apps to pipeline
        couplings = app_platform.api_client.pipeline_coupling.list_by_pipeline(pipeline.uid)
        apps = couplings.map {|c|
          app = prj.apps.find_by(uid: c['app']['id'])
          app.stage = c['stage'].to_sym
          app.pipeline = pipeline

          if app.save
            logger.info("Coupled #{app.named}")
          else
            logger.error("Failed couple #{app.named}")
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
        logger.error("Failed sync #{pipeline.named}")
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
