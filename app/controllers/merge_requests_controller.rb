class MergeRequestsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_merge_request, except: [:index, :new, :create]

  def index
    @merge_requests = @project.merge_requests
    respond_with @merge_requests
  end

  def show
    authorize! :read, @merge_request
    respond_with @merge_request
  end

  def approve
    authorize! :approve, @merge_request
    @merge_request.approve
    respond_with @merge_request
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    authorize! :read, @project
  end

  def set_merge_request
    @merge_request = MergeRequest.find(params[:id])
    @project = @merge_request.project
  end
end
