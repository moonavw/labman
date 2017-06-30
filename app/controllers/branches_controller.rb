class BranchesController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_branch, except: [:index, :new, :create]

  def index
    @branches = @project.branches
    @uncategorized_branches = @branches.reject(&:category)
    @categorized_branches = @branches.select(&:category).group_by(&:category)
    respond_with @branches
  end

  def show
    authorize! :read, @branch
    respond_with @branch
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    authorize! :read, @project
  end

  def set_branch
    @branch = Branch.find(params[:id])
    @project = @branch.project
  end
end
