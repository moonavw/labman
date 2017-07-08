class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable


  belongs_to :team

  has_many :branches, dependent: :destroy
  has_many :merge_requests, dependent: :destroy
  has_many :releases, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :apps, dependent: :destroy
  has_many :pipelines, dependent: :destroy

  validates_uniqueness_of :name, scope: :team

  delegate :code_manager, :issue_tracker, :build_server, :app_platform,
           to: :team

  def builds
    Build.where(:branch_id.in => branch_ids)
  end
end
