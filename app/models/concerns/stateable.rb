module Stateable
  extend ActiveSupport::Concern

  included do
    field :state

    validates_presence_of :state
  end

  def status
    state
  end

  def stated
    "#{self.class.model_name} #{status.to_s.titlecase}"
  end
end
