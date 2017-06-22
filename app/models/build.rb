class Build
  include Mongoid::Document
  include Mongoid::Timestamps

  include RunState

  field :name, type: String

  belongs_to :branch
  belongs_to :app
  belongs_to :issue, required: false


  validates_presence_of :name

  after_create :lock_app
  before_destroy :unlock_app

  def lock_app
    app.update(state: :locked)
    QueueBuildJob.perform_later(id.to_s) if state.pending?
  end

  def unlock_app
    if app.locked_build == self
      app.update(state: :idle)
    end
  end
end
