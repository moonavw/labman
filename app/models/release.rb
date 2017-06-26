class Release
  include Mongoid::Document
  include Mongoid::Timestamps

  include Workable

  field :name, type: String
  field :due_date, type: Date
  field :tag_name, type: String

  belongs_to :project

  has_many :issues

  default_scope -> {desc(:due_date)}

  validates_presence_of :name
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
    BumpReleaseJob.perform_later(self.id.to_s) if can_bump?
  end

  def bumping?
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == BumpReleaseJob.name && args['arguments'].include?(self.id.to_s)
    }
  end

  def rebuild
    return unless branch

    branch.unbuild

    app = project.apps.with_stage(:development).first
    Build.create(name: tag_name, branch: branch, app: app)
  end
end
