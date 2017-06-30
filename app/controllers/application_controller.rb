class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?

  respond_to :html, :json, :js

  rescue_from CanCan::AccessDenied do |exception|
    if request.xhr?
      flash.now[:error] = exception.message
      @error = exception
      respond_with @error, layout: 'error'
    else
      redirect_back fallback_location: root_url, alert: exception.message
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username])
  end
end
