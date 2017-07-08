class MergeRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Requestable
  include Queueable

  field :uid, type: String
  field :url, type: String

  belongs_to :project
  belongs_to :release, inverse_of: nil, required: false
  belongs_to :issue, required: false
  belongs_to :source_branch, class_name: 'Branch', inverse_of: nil, required: false
  belongs_to :target_branch, class_name: 'Branch', inverse_of: nil, required: false

  def can_approve?
    super && source_branch.present? && target_branch.present?
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
