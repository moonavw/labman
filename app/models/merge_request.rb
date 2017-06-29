class MergeRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Requestable
  include Queueable

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

  def approve
    super
    accept
  end

  def accept
    return unless can_accept?

    AcceptMergeRequestJob.perform_later(self.id.to_s) unless queued?(AcceptMergeRequestJob)
  end
end
