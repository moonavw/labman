class App
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Stageable
  include Resourceable
  include Configurable
  include Queueable

  field :uid, type: String
  field :url, type: String
  field :version_name, type: String

  belongs_to :project
  belongs_to :pipeline, required: false

  belongs_to :promoted_from, class_name: 'App', inverse_of: :promoted_to, required: false
  has_many :promoted_to, class_name: 'App', inverse_of: :promoted_from

  has_one :build

  scope :unpipelined, -> {where(pipeline: nil)}
  scope :pipelined, -> {where(:pipeline.ne => nil)}

  validates_uniqueness_of :name, scope: :project

  def locked_build
    build if state.locked?
  end

  def lock
    super && update(promoted_from: nil)
  end

  def can_promote?
    pipeline && next_stage
  end

  def promote
    return unless can_promote?

    self.promoted_to = pipeline.apps.with_stage(next_stage).with_state(:opened)

    PromoteAppJob.perform_later(self.id.to_s) unless queued?(PromoteAppJob)
  end
end
