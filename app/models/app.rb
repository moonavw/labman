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

  belongs_to :promoted_from, class_name: 'App', inverse_of: :promoted_to, required: false
  has_many :promoted_to, class_name: 'App', inverse_of: :promoted_from

  has_one :build

  scope :unpipelined, -> {where(pipeline: nil)}
  scope :pipelined, -> {where(:pipeline.ne => nil)}

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project

  def locked_build
    build if state.locked?
  end

  def promote
    return unless pipeline

    pipeline.promote(self)
  end
end
