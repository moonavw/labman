class ProjectsController < ApplicationController
  before_action :set_team, only: [:index, :new, :create]
  before_action :set_project, except: [:index, :new, :create]

  def index
    @projects = @team.projects
    respond_with @projects
  end

  def show
    authorize! :read, @project
    respond_with @project
  end

  private
  def set_team
    @team = Team.find(params[:team_id])
    authorize! :read, @team
  end

  def set_project
    @project = Project.find(params[:id])
  end
end
