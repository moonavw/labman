class AppPlatform
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :config, type: Hash

  belongs_to :team

  validates_presence_of :name
  validates_uniqueness_of :name


  def api_client
    @client ||= PlatformAPI.connect_oauth(config[:oauth_token])
  end

  def promote(pipeline, source_app, target_apps)
    promotion_params = {
        pipeline: {
            id: pipeline.uid
        },
        source: {
            app: {
                id: source_app.uid
            }
        },
        targets: target_apps.map {|a|
          {
              app: {
                  id: a.uid
              }
          }
        }
    }
    api_client.pipeline_promotion.create(promotion_params)
  end
end
