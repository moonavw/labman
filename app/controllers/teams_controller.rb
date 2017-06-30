class TeamsController < ApplicationController
  before_action :set_team, except: [:index, :new, :create]

  def index
    @teams = Team.all
    respond_with @teams
  end

  def show
    authorize! :read, @team
    respond_with @team
  end

  private
  def set_team
    @team = Team.find(params[:id])
  end
end
