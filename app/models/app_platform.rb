class AppPlatform

  SCHEDULE_JOB = SyncAppPlatformJob

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable
  include Schedulable


  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= PlatformAPI.connect_oauth(config[:oauth_token])
  end
end
