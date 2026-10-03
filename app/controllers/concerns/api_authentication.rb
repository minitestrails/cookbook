# app/controllers/concerns/api_authentication.rb
module ApiAuthentication
  extend ActiveSupport::Concern

  included { before_action :require_api_authentication }

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_api_authentication, **options
    end
  end

  private

  def authenticated?
    resume_api_session
  end

  def current_user
    return nil unless authenticated?
    return @current_user if defined?(@current_user)

    @current_user = Current.api_user
  end

  def require_api_authentication
    resume_api_session || request_api_authentication
  end

  def resume_api_session
    return true if Current.api_token.present?

    api_token = ApiToken.authenticate(bearer_token)
    return false unless api_token

    Current.api_token = api_token

    true
  end

  def bearer_token
    header = request.authorization.to_s
    return unless header.match?(/\ABearer /i)

    header.split(" ", 2).last
  end

  def request_api_authentication
    render json: { error: "Invalid token" }, status: :unauthorized
  end
end
