class Release
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Workable
  include Archivable

  field :due_date, type: Date
  field :tag_name, type: String

  belongs_to :project

  has_many :issues

  default_scope -> {desc(:due_date)}

  validates_uniqueness_of :name, scope: :project


  def work_in_progress
    super if issues.any? || branch
  end

  def branch_name
    "release/v#{name}"
  end

  def branch
    @rc_branch ||= project.branches.where(name: branch_name).first
  end

  def can_bump?
    state.in_progress?
  end

  def bump
    return unless can_bump?
    return if bumping?

    BumpReleaseJob.perform_later(self.id.to_s)
  end

  def bumping?
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == BumpReleaseJob.name && args['arguments'].include?(self.id.to_s)
    }
  end

  def rebuild
    return unless can_rebuild?
    return if rebuilding?

    BuildReleaseJob.perform_later(self.id.to_s)
  end

  def rebuilding?
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == BuildReleaseJob.name && args['arguments'].include?(self.id.to_s)
    }
  end

  def can_rebuild?
    return false unless branch
    return true unless branch.build
    branch.build.name != tag_name
  end

  def can_archive?
    state.done? && super
  end
end
