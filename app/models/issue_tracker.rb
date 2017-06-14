class IssueTracker
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :config, type: Hash

  belongs_to :team

  validates_presence_of :name
  validates_uniqueness_of :name


  def api_client
    @client ||= JIRA::Client.new(config.merge({auth_type: config[:auth_type].to_sym}).symbolize_keys)
  end

  def api_client_issue
    api_client.Issue
  end
end
