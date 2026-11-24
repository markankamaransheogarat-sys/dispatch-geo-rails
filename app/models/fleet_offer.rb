# frozen_string_literal: true

class FleetOffer < ApplicationRecord
  KINDS = %w[truck cargo].freeze
  STATUSES = %w[open matched expired].freeze

  COMPATIBLE_BODIES = {
    "tent" => %w[tent furgon bort],
    "ref" => %w[ref izoterm tent furgon],
    "izoterm" => %w[izoterm tent furgon],
    "furgon" => %w[furgon tent],
    "bort" => %w[bort tral],
    "tral" => %w[tral]
  }.freeze

  has_many :truck_matches, class_name: "CorridorMatch", foreign_key: :truck_offer_id, dependent: :restrict_with_exception
  has_many :cargo_matches, class_name: "CorridorMatch", foreign_key: :cargo_offer_id, dependent: :restrict_with_exception

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :body_type, :origin_city, :dest_city, :external_hash, :expires_at, presence: true

  def compatible_cargo_bodies
    COMPATIBLE_BODIES.fetch(body_type, [ body_type ])
  end
end
