# frozen_string_literal: true

class CorridorMatch < ApplicationRecord
  belongs_to :truck_offer, class_name: "FleetOffer"
  belongs_to :cargo_offer, class_name: "FleetOffer"

  validates :match_kind, inclusion: { in: %w[direct corridor_pickup] }
  validates :status, inclusion: { in: %w[pending notified accepted] }
end
