module Workable
  extend ActiveSupport::Concern
  include Stateable

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    enumerize :state,
              in: [:to_do, :in_progress, :done],
              default: :to_do,
              scope: true

  end

  def work_in_progress
    update(state: :in_progress) if state.to_do?
  end

  def can_close?
    state.in_progress?
  end

  def close
    update(state: :done) if can_close?
  end
end
