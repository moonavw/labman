class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  include Nameable
  include Configurable

  field :private, type: Boolean

  has_one :code_manager
  has_one :build_server
  has_one :issue_tracker
  has_one :app_platform


  has_many :branches, dependent: :destroy
  has_many :merge_requests, dependent: :destroy
  has_many :releases, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :apps, dependent: :destroy
  has_many :pipelines, dependent: :destroy

  has_and_belongs_to_many :members, class_name: 'User', inverse_of: nil, after_remove: :remove_master
  has_and_belongs_to_many :masters, class_name: 'User', inverse_of: nil, after_add: :add_member

  validates_uniqueness_of :name


  def builds
    Build.where(:branch_id.in => branch_ids)
  end

  def tests
    Test.where(:branch_id.in => branch_ids)
  end


  def add_member(user)
    self.members << user unless self.members.include?(user)
  end

  def remove_member(user)
    self.members.delete(user) if self.members.include?(user)
  end

  def add_master(user)
    self.masters << user unless self.masters.include?(user)
  end

  def remove_master(user)
    self.masters.delete(user) if self.masters.include?(user)
  end
end
