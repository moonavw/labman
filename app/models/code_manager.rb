class CodeManager
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  field :config, type: Hash

  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= Gitlab.client(config.symbolize_keys)
  end
end
