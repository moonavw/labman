class Build
  include Mongoid::Document
  include Mongoid::Timestamps

  include RunState

  field :name, type: String

  belongs_to :branch
  belongs_to :app
  belongs_to :issue, required: false


  validates_presence_of :name

  after_create :lock_app
  before_destroy :unlock_app

  def lock_app
    app.update(state: :locked)
  end

  def unlock_app
    app.update(state: :opened) if app.locked_build == self
  end

  def issue_name
    issue.try(:name)
  end

  def issue_name=(value)
    # find_by cause Mongoid::Errors::DocumentNotFound when Mongoid.raise_not_found_error true
    self.issue = Issue.where(name: value).first
  end
end
