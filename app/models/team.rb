class Team
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable

  field :private, type: Boolean

  has_one :code_manager
  has_one :build_server
  has_one :issue_tracker
  has_one :app_platform

  has_many :projects

  has_and_belongs_to_many :members, class_name: 'User', inverse_of: nil, after_remove: :remove_master
  has_and_belongs_to_many :masters, class_name: 'User', inverse_of: nil, after_add: :add_member

  validates_uniqueness_of :name

  private
  def add_member(user)
    self.members << user unless self.members.include?(user)
  end

  def remove_master(user)
    self.masters.delete(user) if self.masters.include?(user)
  end
end
