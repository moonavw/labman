class Release

  BRANCH_PREFIX = 'release/v'
  BUILD_NAME = 'rc'
  PUBLISH_TAG = 'next'
  LIVE_TAG = 'latest'

  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Workable
  include Versionable
  include Archivable
  include Queueable

  field :uid, type: String
  field :due_date, type: Date

  belongs_to :project

  has_many :issues

  default_scope -> {desc(:due_date)}

  validates_uniqueness_of :name, scope: :project
  validates_format_of :name, with: /\A\d+\.\d+\z/

  validates_presence_of :due_date

  after_create :on_created

  def work_in_progress
    super if issues.without_state(:to_do).any? || branch
  end

  def branch_name
    # "release/v#{name}"
    BRANCH_PREFIX + name
  end

  def branch
    @rc_branch ||= project.branches.where(name: branch_name).first
  end

  def can_publish?
    state.in_progress? && super
  end

  def publish
    return unless super

    PublishReleaseJob.perform_later(self.id.to_s) unless queued?(PublishReleaseJob)
  end

  def can_bump?
    state.in_progress? && super
  end

  def bump
    return unless super

    BumpReleaseJob.perform_later(self.id.to_s) unless queued?(BumpReleaseJob)
  end

  def can_close?
    super && tag_name.present? && !can_bump? && !can_publish?
  end

  def close
    return unless super

    CloseReleaseJob.perform_later(self.id.to_s) unless queued?(CloseReleaseJob)
  end

  def can_rebuild?
    return false unless branch.present?
    return false unless tag_name.present?
    return true unless branch.build.present?
    return false unless branch.build.can_rerun?
    tag_name != "v#{branch.build.app.version_name}"
  end

  def rebuild
    return unless can_rebuild?

    app = project.apps.find_by(name: project.config[:RELEASE][:BUILD][:APP])

    config = (project.config[:RELEASE][:BUILD][:CONFIG]||{}).map {|k, v|
      [k, instance_eval(v)]
    }.to_h

    unless branch.build.present?
      branch.create_build(
          name: BUILD_NAME,
          config: config,
          app: app
      ).run
    else
      branch.build.rerun
    end
  end

  def can_archive?
    state.done? && super
  end

  def on_created
    CreateReleaseJob.perform_later(self.id.to_s) unless queued?(CreateReleaseJob)
  end
end
