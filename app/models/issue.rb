class Issue
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Workable

  field :url, type: String

  belongs_to :project
  belongs_to :release, required: false

  has_many :merge_requests

  has_one :build

  validates_uniqueness_of :name, scope: :project

  before_destroy :unbuild

  def unbuild
    build.destroy if build.present?
  end

end
