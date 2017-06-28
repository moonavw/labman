module Stageable
  extend ActiveSupport::Concern

  included do
    extend Enumerize
    extend ActiveModel::Naming

    field :stage
    enumerize :stage,
              in: [:development, :staging, :production],
              scope: true

  end

  def next_stage
    return unless self.stage

    stages = self.class.stage.values
    idx = stages.index(self.stage)
    stages.from(idx + 1).first
  end
end
