module Stageable
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :stage
    enumerize :stage,
              in: [:development, :staging, :production],
              # default: nil,
              scope: true

    # validates_presence_of :stage

  end

  def next_stage
    return unless self.stage

    stages = self.class.stage.values
    idx = stages.index(self.stage)
    stages.from(idx + 1).first
  end
end
