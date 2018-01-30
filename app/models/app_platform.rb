class AppPlatform

  SCHEDULE_JOB = SyncAppPlatformJob

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable
  include Schedulable
  include Queueable


  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= PlatformAPI.connect_oauth(config[:oauth_token])
  end

  def can_sync?
    !queued?(SyncAppPlatformJob)
  end

  def sync
    SyncAppPlatformJob.perform_later(self.id.to_s) if can_sync?
  end
end
