class Test
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Runnable
  include Queueable
  include Configurable

  field :url, type: String

  belongs_to :branch

  validates_format_of :name, with: /\A[0-9a-z-]+\z/

  delegate :project, :protected?,
           to: :branch


  before_destroy :cleanup

  def run
    return unless can_run?

    RunTestJob.perform_later(self.id.to_s) unless queued?(RunTestJob)
  end

  def stop
    return unless super

    StopJobOnBuildServerJob.perform_later(project.id.to_s, job_name)
  end

  def final_config
    (project.config[:TEST][:CONFIG]||{}).map {|k, v|
      [k, instance_eval(v)]
    }.to_h.merge(config||{})
  end

  def job_name_prefix
    project.config[:JENKINS_PROJECT][:TEST]
  end

  def job_name
    "#{job_name_prefix}-#{branch.flat_name}"
  end

  def cleanup
    DeleteJobFromBuildServerJob.perform_later(project.id.to_s, job_name)
  end
end
