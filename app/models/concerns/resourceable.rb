module Resourceable
  extend ActiveSupport::Concern
  include Stateable

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    enumerize :state,
              in: [:opened, :locked],
              default: :opened,
              scope: true
  end

  def lock
    update(state: :locked) if state.opened?
  end

  def unlock
    update(state: :opened) if state.locked?
  end
end
