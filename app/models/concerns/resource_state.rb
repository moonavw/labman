module ResourceState
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :state
    enumerize :state,
              in: [:idle, :locked],
              default: :idle,
              scope: true

    validates_presence_of :state

  end
end