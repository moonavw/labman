# Runnable
module RunState
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :state
    enumerize :state,
              in: [:pending, :running, :completed, :aborted],
              default: :pending,
              scope: true

    field :result
    enumerize :result,
              in: [:success, :failure]

    validates_presence_of :state

  end

  def status
    if state.completed?
      result
    else
      state
    end
  end
end
