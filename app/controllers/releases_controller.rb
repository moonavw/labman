class ReleasesController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_release, except: [:index, :new, :create]

  def index
    @releases = @project.releases.unarchived
    respond_with @releases
  end

  def show
    authorize! :read, @release
    respond_with @release
  end

  def bump
    authorize! :bump, @release
    @release.bump
    respond_with @release
  end

  def rebuild
    authorize! :run, @release
    @release.rebuild
    respond_with @release
  end

  def destroy
    authorize! :update, @release
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
end
