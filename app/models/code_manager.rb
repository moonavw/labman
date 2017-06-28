class CodeManager
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable


  belongs_to :team

  validates_uniqueness_of :name


  def api_client
    @client ||= Gitlab.client(config.symbolize_keys)
  end
end
