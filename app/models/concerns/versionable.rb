module Versionable
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    field :check
    enumerize :check,
              in: [:outdated, :updated],
              scope: true
  end

  def can_bump?
    check == :outdated
  end

  def bump
    update(check: nil) if can_bump?
  end
end
