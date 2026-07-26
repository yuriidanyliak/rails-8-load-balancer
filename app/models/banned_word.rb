class BannedWord < ApplicationRecord
  validates :phrase, presence: true, uniqueness: { case_sensitive: false }
end
