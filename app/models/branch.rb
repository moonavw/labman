class Branch
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :project

  has_one :build, dependent: :destroy

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project

  def category
    ns = name.split('/')
    ns.first if ns.count > 1
  end

  def unbuild
    build.destroy if build
  end
end
