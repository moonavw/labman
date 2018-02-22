class App
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Stageable
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


  def status
    has_build? ? :locked : :opened
  end

  def stated
    "#{self.class.model_name} #{status.to_s.titlecase}"
  end

  def can_promote?
    pipeline.present? && next_stage.present? && promoting_targets.any?
  end

  def promote
    return unless can_promote?

    self.promoted_to = promoting_targets

    PromoteAppJob.perform_later(self.id.to_s) unless queued?(PromoteAppJob)
  end

  def promoting_targets
    release_build_config_keys = project.config[:RELEASE][:BUILD][:CONFIG].keys

    pipeline.apps.with_stage(next_stage).reject(&:has_build?).reject {|t|
      release_build_config_keys.any? {|k|
        t.config[k] == config[k]
      }
    }
  end
end
