class Backend < ApplicationRecord
  scope :healthy, -> { where(healthy: true) }

  validates :host, presence: true, uniqueness: true
  validates :weight, numericality: { greater_than: 0 }
  validates :active_connections, :times_selected, numericality: { greater_than_or_equal_to: 0 }

  def acquire!
    increment!(:times_selected)
    increment!(:active_connections)
  end

  def release!
    decrement!(:active_connections) if active_connections > 0
  end

  def mark_unhealthy!
    update!(healthy: false)
  end

  def mark_healthy!
    update!(healthy: true)
  end
end
