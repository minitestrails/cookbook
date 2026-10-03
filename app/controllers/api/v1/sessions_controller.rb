# app/controllers/api/v1/sessions_controller.rb
class Api::V1::SessionsController < ApiController
  allow_unauthenticated_access only: :create
  rate_limit to: 10,
             within: 3.minutes,
             only: :create,
             with: -> do
               render json: {
                        error: "Try again later."
                      },
                      status: :too_many_requests
             end

  def create
    if (user = User.authenticate_by(session_params))
      api_token = user.api_tokens.create!
      render json: {
               token: api_token.raw_token,
               user: {
                 id: user.id,
                 email_address: user.email_address
               }
             },
             status: :created
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def destroy
    Current.api_token.destroy!

    head :no_content
  end

  private

  def session_params
    params.permit(:email_address, :password)
  end
end
