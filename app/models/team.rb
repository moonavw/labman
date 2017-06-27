class Team
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  has_one :code_manager
  has_one :build_server
  has_one :issue_tracker
  has_one :app_platform

  has_many :projects

  validates_uniqueness_of :name
end
