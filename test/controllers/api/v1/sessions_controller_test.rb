# test/controllers/api/v1/sessions_controller_test.rb
require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "logs in with valid credentials" do
    post api_v1_sessions_url,
         params: {
           email_address: users(:alice).email_address,
           password: "password"
         },
         as: :json

    assert_response :created
    assert response.parsed_body["token"].present?
    assert_equal users(:alice).email_address,
                 response.parsed_body.dig("user", "email_address")
  end

  test "rejects login with a bad password" do
    post api_v1_sessions_url,
         params: {
           email_address: users(:alice).email_address,
           password: "wrong-password"
         },
         as: :json

    assert_response :unauthorized
    assert_equal "Invalid email or password", response.parsed_body["error"]
  end

  test "revokes the bearer token" do
    post api_v1_sessions_url,
         params: {
           email_address: users(:alice).email_address,
           password: "password"
         },
         as: :json

    token = response.parsed_body.fetch("token")
    headers = { "Authorization" => "Bearer #{token}" }

    delete api_v1_session_url, headers: headers, as: :json
    assert_response :no_content

    assert_no_difference "Recipe.count" do
      post api_v1_recipes_url,
           params: {
             recipe: {
               title: "After revoke"
             }
           },
           headers: headers,
           as: :json
    end
    assert_response :unauthorized
    assert_equal "Invalid token", response.parsed_body["error"]
  end

  test "rate limits login attempts" do
    Rails.cache.clear

    10.times do
      post api_v1_sessions_url,
           params: {
             email_address: users(:alice).email_address,
             password: "wrong-password"
           },
           as: :json
    end

    post api_v1_sessions_url,
         params: {
           email_address: users(:alice).email_address,
           password: "wrong-password"
         },
         as: :json

    assert_response :too_many_requests
    assert_equal "Try again later.", response.parsed_body["error"]

    Rails.cache.clear
  end
end
