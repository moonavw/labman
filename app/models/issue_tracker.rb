class IssueTracker

  SCHEDULE_JOB = SyncIssueTrackerJob

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable
  include Schedulable


  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= JIRA::Client.new(config.merge({auth_type: config[:auth_type].to_sym}).symbolize_keys)
  end

  def api_client_issue
    api_client.Issue
  end
end
