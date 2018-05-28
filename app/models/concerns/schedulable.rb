module Schedulable
  extend ActiveSupport::Concern

  included do
    field :interval, type: String

    after_save :reschedule
  end

  def schedule(job_klass = self.class.const_get(:SCHEDULE_JOB))
    job_name = "#{job_klass.name}-#{self.id.to_s}"

    Sidekiq::Cron::Job.destroy(job_name)
    job = Sidekiq::Cron::Job.new(name: job_name, cron: self.interval, class: job_klass.name, args: [self.id.to_s])
    [job.save, job.errors]
  end

  def reschedule
    if self.interval_changed?
      schedule
    end
  end
end
