# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2026_11_24_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "corridor_matches", force: :cascade do |t|
    t.bigint "truck_offer_id", null: false
    t.bigint "cargo_offer_id", null: false
    t.string "match_kind", null: false
    t.float "detour_km", null: false
    t.bigint "spread_rub"
    t.float "score", null: false
    t.string "status", default: "pending", null: false
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_offer_id"], name: "index_corridor_matches_on_cargo_offer_id"
    t.index ["status", "score"], name: "idx_corridor_matches_status_score"
    t.index ["truck_offer_id", "cargo_offer_id"], name: "idx_corridor_matches_unique", unique: true
    t.index ["truck_offer_id"], name: "index_corridor_matches_on_truck_offer_id"
  end

  create_table "fleet_offers", force: :cascade do |t|
    t.string "kind", null: false
    t.string "body_type", null: false
    t.string "origin_city", null: false
    t.float "origin_lat", null: false
    t.float "origin_lon", null: false
    t.string "dest_city", null: false
    t.float "dest_lat", null: false
    t.float "dest_lon", null: false
    t.bigint "price_rub"
    t.string "status", default: "open", null: false
    t.string "external_hash", null: false
    t.string "source_chat"
    t.string "contact_handle"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_hash"], name: "index_fleet_offers_on_external_hash", unique: true
    t.index ["kind", "status", "body_type"], name: "idx_fleet_offers_matching"
    t.index ["origin_lat", "origin_lon"], name: "idx_fleet_offers_origin_coords"
    t.check_constraint "kind::text = ANY (ARRAY['truck'::character varying, 'cargo'::character varying]::text[])", name: "chk_fleet_offers_kind"
    t.check_constraint "status::text = ANY (ARRAY['open'::character varying, 'matched'::character varying, 'expired'::character varying]::text[])", name: "chk_fleet_offers_status"
  end

  add_foreign_key "corridor_matches", "fleet_offers", column: "cargo_offer_id"
  add_foreign_key "corridor_matches", "fleet_offers", column: "truck_offer_id"
end
