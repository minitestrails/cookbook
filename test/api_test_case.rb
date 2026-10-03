# test/api_test_case.rb
require "test_helper"
require_relative "test_helpers/api_test_helper"

class ApiTestCase < ActionDispatch::IntegrationTest
  include ApiTestHelper
end
