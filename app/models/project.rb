class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :config, type: Hash

  belongs_to :team

  has_many :branches, dependent: :destroy
  has_many :releases, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :apps, dependent: :destroy
  has_many :pipelines, dependent: :destroy

  validates_presence_of :name
  validates_uniqueness_of :name

  delegate :code_manager, :issue_tracker, :build_server, :platform,
           to: :team

  def builds
    branch_ids = branches.map(&:id)
    Build.where(:branch_id.in => branch_ids)
  end
end
