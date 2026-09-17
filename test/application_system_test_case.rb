# test/application_system_test_case.rb
require "test_helper"
require_relative "test_helpers/download_test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include DownloadTestHelper

  driver = ENV["HEADFUL"] == "1" ? :chrome : :headless_chrome
  driven_by :selenium, using: driver, screen_size: [1400, 1400] do |options|
    options.add_preference(
      :download,
      prompt_for_download: false,
      default_directory: DownloadTestHelper::DOWNLOAD_PATH.to_s
    )
    options.add_preference(
      :browser,
      set_download_behavior: {
        behavior: "allow"
      }
    )
  end

  teardown { Capybara.reset_sessions! }

  def sign_in_to_ui_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id

      visit new_session_url

      page.driver.browser.manage.add_cookie(
        name: :session_id,
        value: cookie_jar[:session_id],
        sameSite: :Lax,
        httpOnly: true
      )
    end
  end
end
