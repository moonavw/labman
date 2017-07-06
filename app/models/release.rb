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
    state.in_progress? && super && Release.with_state(:in_progress).count == 1
  end

  def bump
    return unless super

    BumpReleaseJob.perform_later(self.id.to_s) unless queued?(BumpReleaseJob)
  end

  def can_rebuild?
    return false unless branch
    return false unless tag_name
    return true unless branch.build
    return false unless branch.build.can_rerun?
    tag_name != "v#{branch.build.app.version_name}"
  end

  def rebuild
    return unless can_rebuild?

    app = project.apps.with_stage(:development).first

    config = project.config[:RELEASE][:BUILD][:CONFIG].map {|k, v|
      [k, instance_eval(v)]
    }.to_h

    unless branch.build
      branch.create_build(name: project.config[:RELEASE][:BUILD][:NAME], config: config, app: app)
    else
      branch.build.reset
    end

    BuildReleaseJob.perform_later(self.id.to_s) unless queued?(BuildReleaseJob)
  end

  def can_archive?
    state.done? && super
  end
end
