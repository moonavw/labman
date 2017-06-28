class Build
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Runnable


  belongs_to :branch
  belongs_to :app
  belongs_to :issue, required: false


  delegate :project,
           to: :branch

  after_create :lock_app
  before_destroy :unlock_app

  def lock_app
    app.lock
  end

  def unlock_app
    app.unlock if app.locked_build == self
  end

  def issue_name
    issue.try(:name)
  end

  def issue_name=(value)
    # find_by cause Mongoid::Errors::DocumentNotFound when Mongoid.raise_not_found_error true
    self.issue = Issue.where(name: value).first
  end

  def run
    return unless can_run?
    return if running?

    RunBuildJob.perform_later(self.id.to_s)
  end

  def running?
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == RunBuildJob.name && args['arguments'].include?(self.id.to_s)
    }
  end
end
