module Archivable
  extend ActiveSupport::Concern

  included do
    field :archived_at, type: Time

    scope :unarchived, -> {where(archived_at: nil)}
    scope :archived, -> {where(:archived_at.ne => nil)}
  end

  def archived?
    !!archived_at
  end

  def can_archive?
    !archived?
  end

  def archive
    update(archived_at: Time.now)
  end
end
