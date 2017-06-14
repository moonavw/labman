class Pipeline
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :uid, type: String

  belongs_to :project

  has_many :apps

  validates_presence_of :name
  validates_uniqueness_of :name
end
