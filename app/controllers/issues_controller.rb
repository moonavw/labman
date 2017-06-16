class IssuesController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_issue, except: [:index, :new, :create]

  def index
    @issues = @project.issues
    respond_with @issues
  end

  def show
    respond_with @issue
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_issue
    @issue = Issue.find(params[:id])
    @project = @issue.project
  end
end
