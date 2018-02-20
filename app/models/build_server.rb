class BuildServer

  SCHEDULE_JOB = SyncBuildServerJob

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable
  include Schedulable
  include Queueable


  belongs_to :project

  validates_uniqueness_of :name


  def api_client
    @client ||= JenkinsApi::Client.new(config.symbolize_keys)
  end

  def can_sync?
    !queued?(SyncBuildServerJob)
  end

  def sync
    SyncBuildServerJob.perform_later(self.id.to_s) if can_sync?
  end
end
