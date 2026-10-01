# test/integration/session_integration_test.rb
require "test_helper"

class SessionIntegrationTest < ActionDispatch::IntegrationTest
  test "signs in" do
    get new_session_url
    assert_response :success

    post session_url,
         params: {
           email_address: users(:alice).email_address,
           password: "password"
         }
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end

  test "rejects invalid password" do
    post session_url,
         params: {
           email_address: users(:alice).email_address,
           password: "wrong"
         }
    assert_redirected_to new_session_url
    follow_redirect!
    assert_select "form"
  end

  test "signs out" do
    sign_in_as users(:alice)

    delete session_url
    assert_redirected_to new_session_url
    assert_empty cookies["session_id"]
  end

  test "rate limits sign in attempts" do
    Rails.cache.clear

    10.times do
      post session_url, params: {
        email_address: users(:alice).email_address,
        password: "wrong"
      }
    end

    post session_url, params: {
      email_address: users(:alice).email_address,
      password: "wrong"
    }

    assert_redirected_to new_session_url
    assert_equal "Try again later.", flash[:alert]
  end
end
