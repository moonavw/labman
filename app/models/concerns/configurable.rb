module Configurable
  extend ActiveSupport::Concern

  included do
    field :config, type: Hash

  end

  def readable_config
    config.to_yaml.lines[1..-1].join
  end
end
