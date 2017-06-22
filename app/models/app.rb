class App
  include Mongoid::Document
  include Mongoid::Timestamps

  include PipelineStage
  include ResourceState


  field :name, type: String
  field :config, type: Hash
  field :uid, type: String
  field :url, type: String

  belongs_to :project
  belongs_to :pipeline, required: false

  has_many :builds

  scope :unpipelined, -> {where(pipeline: nil)}

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project

  def locked_build
    builds.last if state.locked?
  end
end
