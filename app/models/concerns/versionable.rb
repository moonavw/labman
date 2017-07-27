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
    update(check: nil) if can_bump?
  end

  def can_publish?
    tag_name.present? &&
        tag_name != published_on &&
        published_on != self.class.const_get(:PUBLISH_TAG)
  end

  def publish
    update(published_on: self.class.const_get(:PUBLISH_TAG)) if can_publish?
  end
end
