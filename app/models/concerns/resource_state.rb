# Resourceable
module ResourceState
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :state
    enumerize :state,
              in: [:opened, :locked],
              default: :opened,
              scope: true

    validates_presence_of :state

  end

  def lock
    update(state: :locked) if state.opened?
  end

  def unlock
    update(state: :opened) if state.locked?
  end
end
