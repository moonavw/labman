module Requestable
  extend ActiveSupport::Concern
  include Stateable

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    enumerize :state,
              in: [:opened, :reviewed, :approved, :accepted],
              default: :opened,
              scope: true
  end

  def can_approve?
    state.reviewed?
  end

  def approve
    update(state: :approved) if can_approve?
  end

  def can_accept?
    state.approved?
  end

  def accept
    update(state: :accepted) if can_accept?
  end
end
