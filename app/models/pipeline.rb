class Pipeline
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  field :uid, type: String

  belongs_to :project

  has_many :apps

  validates_uniqueness_of :name, scope: :project

end
