class Branch
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String

  belongs_to :project

  has_many :builds, dependent: :destroy

  validates_presence_of :name
  validates_uniqueness_of :name
end
