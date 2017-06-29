module Queueable
  extend ActiveSupport::Concern

  def queued?(job_klass)
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == job_klass.name && args['arguments'].include?(self.id.to_s)
    }
  end
end
