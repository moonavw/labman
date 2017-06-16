class BuildsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_build, except: [:index, :new, :create]

  def index
    @builds = @project.builds
    @builds = @builds.where(app: @app) if @app
    @builds = @builds.where(branch: @branch) if @branch
    respond_with @builds
  end

  def new
    @build = Build.new
    @build.app = @app if @app
    @build.branch = @branch if @branch
    respond_with @build
  end

  def create
    @build = Build.create(build_params)
    respond_with @build
  end

  def show
    respond_with @build
  end

  def edit
    respond_with @build
  end

  def update
    @build.update(build_params)
    respond_with @build
  end

  def destroy
    @build.destroy
    respond_with @build
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    @app = @project.apps.find(params[:app_id]) if params[:app_id]
    @branch = @project.branches.find(params[:branch_id]) if params[:branch_id]
  end

  def build_params
    params.require(:build).permit!
  end

  def set_build
    @build = Build.find(params[:id])
    @project = @build.branch.project
  end
end
