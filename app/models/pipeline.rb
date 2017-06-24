class Pipeline
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :uid, type: String

  belongs_to :project

  has_many :apps

  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project

  def promote(app)
    return unless app.pipeline == self

    next_stage = app.next_stage
    return unless next_stage

    targets = apps.with_stage(next_stage).with_state(:opened)
    project.app_platform.promote(self, app, targets)
  end
end
