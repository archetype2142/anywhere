class AuthToken < ApplicationRecord
    scope :valid, -> { where('expires_at > ?', Time.current).order(created_at: :desc) }
end
