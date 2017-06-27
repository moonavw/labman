class Pipeline
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  field :uid, type: String

  belongs_to :project

  has_many :apps

  validates_uniqueness_of :name, scope: :project

  def promote(app)
    return unless app.pipeline == self

    next_stage = app.next_stage
    return unless next_stage

    app.promoted_to = apps.with_stage(next_stage).with_state(:opened)

    PromoteAppJob.perform_later(app.id.to_s)
  end
end
