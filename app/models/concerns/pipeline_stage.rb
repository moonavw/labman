# Stageable
module PipelineStage
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
end