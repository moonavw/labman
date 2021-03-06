class PromoteAppJob < ApplicationJob
  queue_as :default

  def perform(*app_ids)
    App.pipelined.where(:id.in => app_ids).each {|app|
      promote_app(app)
    }
  end

  private
  def promote_app(app)
    logger.info("Promoting #{app.named} in #{app.pipeline.named}")
    logger.info("Stage from #{app.stage} to #{app.next_stage}")
    logger.info("Targets: #{app.promoted_to.map(&:name)}")

    prj = app.project
    app_platform = prj.app_platform

    promotion_params = {
        pipeline: {
            id: app.pipeline.uid
        },
        source: {
            app: {
                id: app.uid
            }
        },
        targets: app.promoted_to.map {|a|
          {
              app: {
                  id: a.uid
              }
          }
        }
    }
    promotion = app_platform.api_client.pipeline_promotion.create(promotion_params)

    logger.info("Created promotion for #{app.named}, wait a few sec to check status")

    begin
      sleep 5
      promotion = app_platform.api_client.pipeline_promotion.info(promotion['id'])

      logger.info("Promotion status: #{promotion['status']}")

    end while promotion['status'] != 'completed'

    logger.info("Promoted #{app.named}")

    target_ids = app.promoted_to.map(&:id)
    SyncAppVersionJob.perform_later(*target_ids.map(&:to_s))
  end
end
