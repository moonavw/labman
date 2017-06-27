module Nameable
  extend ActiveSupport::Concern

  included do
    field :name, type: String

    validates_presence_of :name
  end

  def named
    "#<#{self.class.model_name}:#{name}>"
  end
end
