module Configurable
  extend ActiveSupport::Concern

  included do
    field :config, type: Hash

  end

  def readable_config
    config.to_yaml.gsub(/!ruby\/.+/, '')
  end

  def readable_config=(value)
    self.config = YAML.safe_load(value)
  end
end
