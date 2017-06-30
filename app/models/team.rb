class Team
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  has_one :code_manager
  has_one :build_server
  has_one :issue_tracker
  has_one :app_platform

  has_many :projects

  has_and_belongs_to_many :users, inverse_of: nil
  has_and_belongs_to_many :masters, class_name: 'User', inverse_of: nil

  validates_uniqueness_of :name

  scope :joined_in, ->(user) {self.or(user_ids: user, master_ids: user)}
  scope :managed_by, ->(user) {where(master_ids: user)}

  def members
    (users|masters)
  end

  def joined_in?(user)
    members.include?(user)
  end

  def managed_by?(user)
    masters.include?(user)
  end
end
