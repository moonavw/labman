class Release
  include Mongoid::Document
  include Mongoid::Timestamps

  include WorkState

  field :name, type: String
  field :due_date, type: Date
  field :tag_name, type: String

  belongs_to :project

  has_many :issues

  default_scope -> {desc(:due_date)}

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project
end
