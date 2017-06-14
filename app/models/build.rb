class Build
  include Mongoid::Document
  include Mongoid::Timestamps

  include RunState

  field :name, type: String

  belongs_to :branch
  belongs_to :app, required: false
  belongs_to :issue, required: false


  validates_presence_of :name
end
