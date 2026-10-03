# test/test_helpers/api_test_helper.rb
module ApiTestHelper
  def bearer_token_for(user)
    api_token = user.api_tokens.create!

    { "Authorization" => "Bearer #{api_token.raw_token}" }
  end
end
