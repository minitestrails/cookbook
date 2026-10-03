# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :api_token
  delegate :user, to: :session, allow_nil: true

  def api_user
    api_token&.user
  end
end
