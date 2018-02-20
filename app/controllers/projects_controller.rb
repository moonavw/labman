class ProjectsController < ApplicationController
  before_action :set_project, except: [:index, :new, :create]

  def index
    @projects = Project.all
    respond_with @projects
  end

  def show
    authorize! :read, @project
    respond_with @project
  end

  def master
    @user = @project.members.find(params[:user_id])
    authorize! :master, @project
    if @project.masters.include?(@user)
      @project.remove_master(@user)
    else
      @project.add_master(@user)
    end
    respond_with @project
  end

  def sync
    @sync_type = params[:type]
    authorize! :master, @project
    case @sync_type
      when 'code_manager'
        @project.code_manager.sync
      when 'app_platform'
        @project.app_platform.sync
      when 'issue_tracker'
        @project.issue_tracker.sync
      when 'build_server'
        @project.build_server.sync
      else
        # nothing
    end
    respond_with @project
  end

  private
  def set_project
    @project = Project.find(params[:id])
  end
end
