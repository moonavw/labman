class Release
  include Mongoid::Document
  include Mongoid::Timestamps

  include WorkState

  field :name, type: String
  field :date, type: Date
  field :tags, type: Array

  belongs_to :project

  has_many :issues

  default_scope -> {desc(:date)}

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project
end
