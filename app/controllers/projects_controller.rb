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
        @project.code_manager.schedule
      when 'app_platform'
        @project.app_platform.sync
        @project.app_platform.schedule
      when 'issue_tracker'
        @project.issue_tracker.sync
        @project.issue_tracker.schedule
      when 'build_server'
        @project.build_server.sync
        @project.build_server.schedule
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
