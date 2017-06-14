# Workable
module WorkState
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :state
    enumerize :state,
              in: [:todo, :in_progress, :done],
              default: :todo,
              scope: true

    validates_presence_of :state

  end
end
