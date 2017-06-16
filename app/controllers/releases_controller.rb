class ReleasesController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_release, except: [:index, :new, :create]

  def index
    @releases = @project.releases
    respond_with @releases
  end

  def show
    respond_with @release
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_release
    @release = Release.find(params[:id])
    @project = @release.project
  end
end
