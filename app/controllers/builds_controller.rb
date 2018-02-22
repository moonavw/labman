class BuildsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_build, except: [:index, :new, :create]

  def index
    @builds = @project.builds
    @builds = @builds.where(app: @app) if @app.present?
    @builds = @builds.where(branch: @branch) if @branch.present?
    respond_with @builds
  end

  def new
    @build = Build.new
    @build.app = @app if @app.present?
    @build.branch = @branch if @branch.present?
    respond_with @build
  end

  def create
    @build = Build.new(build_params)
    authorize! :create, @build
    @build.run if @build.save

    respond_with @build
  end

  def show
    authorize! :read, @build
    respond_with @build
  end

  def edit
    respond_with @build
  end

  def update
    authorize! :update, @build
    @build.rerun if @build.update(build_params)
    respond_with @build
  end

  def stop
    authorize! :update, @build
    @build.stop
    respond_with @build
  end

  def destroy
    authorize! :destroy, @build
    @build.destroy
    respond_with @build
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    authorize! :read, @project
    @app = @project.apps.find(params[:app_id]) if params[:app_id].present?
    @branch = @project.branches.find(params[:branch_id]) if params[:branch_id].present?
  end

  def build_params
    params.require(:build).permit!
  end

  def set_build
    @build = Build.find(params[:id])
    @project = @build.project
  end
end
