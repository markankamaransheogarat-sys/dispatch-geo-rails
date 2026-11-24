# frozen_string_literal: true

class CreateDispatchCore < ActiveRecord::Migration[7.2]
  def change
    create_table :fleet_offers do |t|
      t.string :kind, null: false
      t.string :body_type, null: false
      t.string :origin_city, null: false
      t.float :origin_lat, null: false
      t.float :origin_lon, null: false
      t.string :dest_city, null: false
      t.float :dest_lat, null: false
      t.float :dest_lon, null: false
      t.bigint :price_rub
      t.string :status, null: false, default: "open"
      t.string :external_hash, null: false
      t.string :source_chat
      t.string :contact_handle
      t.datetime :expires_at, null: false
      t.timestamps
    end

    add_index :fleet_offers, :external_hash, unique: true
    add_index :fleet_offers, %i[kind status body_type], name: "idx_fleet_offers_matching"
    add_index :fleet_offers, %i[origin_lat origin_lon], name: "idx_fleet_offers_origin_coords"
    add_check_constraint :fleet_offers, "kind IN ('truck', 'cargo')", name: "chk_fleet_offers_kind"
    add_check_constraint :fleet_offers, "status IN ('open', 'matched', 'expired')", name: "chk_fleet_offers_status"

    create_table :corridor_matches do |t|
      t.references :truck_offer, null: false, foreign_key: { to_table: :fleet_offers }
      t.references :cargo_offer, null: false, foreign_key: { to_table: :fleet_offers }
      t.string :match_kind, null: false
      t.float :detour_km, null: false
      t.bigint :spread_rub
      t.float :score, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :notified_at
      t.timestamps
    end

    add_index :corridor_matches, %i[truck_offer_id cargo_offer_id], unique: true, name: "idx_corridor_matches_unique"
    add_index :corridor_matches, %i[status score], name: "idx_corridor_matches_status_score"
  end
end
