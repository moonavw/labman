class AppsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_app, except: [:index, :new, :create]

  def index
    @apps = @project.apps.unpipelined
    @pipelines = @project.pipelines
    respond_with @apps
  end

  def show
    respond_with @app
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_app
    @app = App.find(params[:id])
    @project = @app.project
  end
end
