# Workable
module WorkState
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :state
    enumerize :state,
              in: [:to_do, :in_progress, :done],
              default: :to_do,
              scope: true

    validates_presence_of :state

  end
end
