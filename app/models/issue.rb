class Issue
  include Mongoid::Document
  include Mongoid::Timestamps

  include WorkState

  field :name, type: String

  belongs_to :project
  belongs_to :release, required: false

  has_many :builds

  validates_presence_of :name
  validates_uniqueness_of :name

end
