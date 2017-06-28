class MergeRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Requestable

  field :target_branch_name, type: String
  field :uid, type: String
  field :url, type: String

  belongs_to :branch
  belongs_to :release, inverse_of: nil, required: false
  belongs_to :issue, required: false

  delegate :project,
           to: :branch


  alias_method :source_branch, :branch

  def target_branch
    @t_branch ||= project.branches.where(name: target_branch_name).first
  end

  def accept
    return unless can_accept?
    return if accepting?

    AcceptMergeRequestJob.perform_later(self.id.to_s)
  end

  def accepting?
    queue = Sidekiq::Queue.new
    queue.any? {|job|
      args = job.args.first
      args['job_class'] == BumpReleaseJob.name && args['arguments'].include?(self.id.to_s)
    }
  end
end
