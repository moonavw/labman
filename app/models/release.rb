class Release
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Workable
  include Versionable
  include Archivable
  include Queueable

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
    state.in_progress? && super
  end

  def bump
    return unless super

    BumpReleaseJob.perform_later(self.id.to_s) unless queued?(BumpReleaseJob)
  end

  def can_rebuild?
    return false unless branch
    return false unless tag_name
    return true unless branch.build
    branch.build.name != tag_name
  end

  def rebuild
    return unless can_rebuild?

    app = project.apps.with_stage(:development).first

    config = project.config['RELEASE_BUILD_CONFIG'].map {|k, v|
      [k, instance_eval(v)]
    }.to_h

    branch.unbuild
    branch.create_build(name: tag_name, config: config, app: app)

    BuildReleaseJob.perform_later(self.id.to_s) unless queued?(BuildReleaseJob)
  end

  def can_archive?
    state.done? && super
  end
end
