module Versionable
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    # extend ActiveModel::Naming

    field :check
    enumerize :check,
              in: [:outdated, :updated],
              scope: true

    field :tag_name, type: String
    field :published_on, type: String
  end

  def can_bump?
    check == :outdated
  end

  def bump
    update(check: :updated) if can_bump?
  end

  def can_publish?
    return false if tag_name.nil?
    return false if can_bump?
    tag_name != published_on
  end

  def publish
    update(published_on: tag_name) if can_publish?
  end
end
