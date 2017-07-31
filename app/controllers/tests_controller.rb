class TestsController < ApplicationController
  before_action :set_project, only: [:index, :new, :create]
  before_action :set_test, except: [:index, :new, :create]

  def index
    @tests = @project.tests
    @tests = @tests.where(branch: @branch) if @branch.present?
    respond_with @tests
  end

  def new
    @test = Test.new
    @test.branch = @branch if @branch.present?
    respond_with @test
  end

  def create
    @test = Test.new(test_params)
    authorize! :run, @test
    @test.run if @test.save

    respond_with @test
  end

  def show
    authorize! :read, @test
    respond_with @test
  end

  def rerun
    authorize! :run, @test
    @test.rerun
    respond_with @test
  end

  def destroy
    authorize! :destroy, @test
    @test.destroy
    respond_with @test
  end

  private
  def set_project
    @project = Project.find(params[:project_id])
    authorize! :read, @project
    @branch = @project.branches.find(params[:branch_id]) if params[:branch_id].present?
  end

  def test_params
    params.require(:test).permit!
  end

  def set_test
    @test = Test.find(params[:id])
    @project = @test.project
  end
end
