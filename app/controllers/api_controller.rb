# app/controllers/api_controller.rb
class ApiController < ActionController::API
  include ApiAuthentication
  include ActionPolicy::Controller

  rescue_from ActiveRecord::RecordNotFound, with: :deny_not_found
  rescue_from ActionPolicy::Unauthorized, with: :deny_forbidden

  authorize :user, through: :current_user

  private

  def deny_not_found(_exception)
    render json: { error: "Not found" }, status: :not_found
  end

  def deny_forbidden(_exception)
    head :forbidden
  end
end
