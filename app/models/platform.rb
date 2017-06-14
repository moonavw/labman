class Platform
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :config, type: Hash

  belongs_to :team

  validates_presence_of :name
  validates_uniqueness_of :name


  def api_client
    @client ||= PlatformAPI.connect_oauth(config[:oauth_token])
  end
end
