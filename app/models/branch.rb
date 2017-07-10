class Branch
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  field :commit, type: String
  field :protected, type: Boolean

  belongs_to :project

  has_one :build, dependent: :destroy

  has_many :outgoing_merges, class_name: 'MergeRequest', inverse_of: :source_branch
  has_many :incoming_merges, class_name: 'MergeRequest', inverse_of: :target_branch

  validates_uniqueness_of :name, scope: :project

  def category
    ns = name.split('/')
    ns.first if ns.count > 1
  end

  def unbuild
    build.destroy if build.present?
  end

  def flat_name
    name.gsub('/', '-')
  end
end
