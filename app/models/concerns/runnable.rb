module Runnable
  extend ActiveSupport::Concern
  include Stateable

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    enumerize :state,
              in: [:pending, :running, :completed, :aborted],
              default: :pending,
              scope: true

    field :result
    enumerize :result,
              in: [:success, :failure]

  end

  def status
    return result if state.completed?

    super
  end

  def can_run?
    state.pending?
  end

  def can_rerun?
    state.completed? || state.aborted?
  end

  def run
    update(state: :running) if can_run?
  end

  def rerun
    update(state: :pending) if can_rerun?
    run
  end
end
