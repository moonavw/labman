class CodeManager

  SCHEDULE_JOB = SyncCodeManagerJob

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable
  include Schedulable
  include Queueable


  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= Gitlab.client(config.symbolize_keys)
  end

  def can_sync?
    !queued?(SyncCodeManagerJob)
  end

  def sync
    SyncCodeManagerJob.perform_later(self.id.to_s) if can_sync?
  end
end
