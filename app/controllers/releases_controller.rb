class ReleasesController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_release, except: [:index, :new, :create]

  def index
    @releases = @project.releases.unarchived
    respond_with @releases
  end

  def new
    @release = @project.releases.new
    authorize! :create, @release
    respond_with @release
  end

  def create
    @release = @project.releases.new(release_params)
    authorize! :create, @release
    @release.save

    respond_with @release
  end

  def show
    authorize! :read, @release
    respond_with @release
  end

  def bump
    authorize! :update, @release
    @release.bump
    respond_with @release
  end

  def publish
    authorize! :update, @release
    @release.publish
    respond_with @release
  end

  def rebuild
    authorize! :update, @release
    @release.rebuild
    respond_with @release
  end

  def close
    authorize! :update, @release
    @release.close
    respond_with @release
  end

  def destroy
    authorize! :destroy, @release
    @release.archive
    respond_with @release
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    authorize! :read, @project
  end

  def set_release
    @release = Release.find(params[:id])
    @project = @release.project
  end

  def release_params
    params.require(:release).permit!
  end
end
