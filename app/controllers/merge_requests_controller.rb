class MergeRequestsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_merge_request, except: [:index, :new, :create]

  def index
    @merge_requests = @project.merge_requests
    @merge_requests = @merge_requests.where(branch: @branch) if @branch
    @merge_requests = @merge_requests.where(release: @release) if @release
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
    @release = @project.releases.find(params[:release_id]) if params[:release_id]
    @branch = @project.branches.find(params[:branch_id]) if params[:branch_id]
  end

  def set_merge_request
    @merge_request = MergeRequest.find(params[:id])
    @project = @merge_request.project
  end
end
