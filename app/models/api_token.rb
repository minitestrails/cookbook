# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user

  attr_accessor :raw_token

  before_validation :generate_token, on: :create

  def self.authenticate(raw_token)
    return if raw_token.blank?

    find_by(token_digest: digest(raw_token))
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end

  private

  def generate_token
    self.raw_token = SecureRandom.hex(32)
    self.token_digest = self.class.digest(raw_token)
  end
end
