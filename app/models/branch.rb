class Branch
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  belongs_to :project

  has_many :merge_requests, dependent: :destroy

  has_one :build, dependent: :destroy

  validates_uniqueness_of :name, scope: :project

  def category
    ns = name.split('/')
    ns.first if ns.count > 1
  end

  def unbuild
    build.destroy if build
  end
end
