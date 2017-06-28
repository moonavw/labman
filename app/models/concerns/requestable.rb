module Requestable
  extend ActiveSupport::Concern
  include Stateable

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    enumerize :state,
              in: [:opened, :approved, :accepted],
              default: :opened,
              scope: true
  end

  def can_accept?
    state.approved?
  end
end
