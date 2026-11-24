# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Geo::FindCorridorMatchesQuery do
  it "finds direct Moscow->SPb matches and en-route Tver->Veliky Novgorod corridor pickups while rejecting off-corridor cargo" do
    # Truck: Moscow (55.7558, 37.6173) -> Saint Petersburg (59.9343, 30.3351), tent
    truck = FleetOffer.create!(
      kind: "truck", body_type: "tent",
      origin_city: "Moscow", origin_lat: 55.7558, origin_lon: 37.6173,
      dest_city: "Saint Petersburg", dest_lat: 59.9343, dest_lon: 30.3351,
      price_rub: 80_000, status: "open", external_hash: "t1", expires_at: 24.hours.from_now
    )

    # Cargo 1: Direct Moscow -> SPb (furgon is compatible with tent)
    direct = FleetOffer.create!(
      kind: "cargo", body_type: "furgon",
      origin_city: "Khimki", origin_lat: 55.8970, origin_lon: 37.4297,
      dest_city: "Shushary", dest_lat: 59.8055, dest_lon: 30.3806,
      price_rub: 110_000, status: "open", external_hash: "c_direct", expires_at: 24.hours.from_now
    )

    # Cargo 2: On-corridor Tver (56.8587, 35.9176) -> Veliky Novgorod (58.5215, 31.2755)
    corridor = FleetOffer.create!(
      kind: "cargo", body_type: "tent",
      origin_city: "Tver", origin_lat: 56.8587, origin_lon: 35.9176,
      dest_city: "Veliky Novgorod", dest_lat: 58.5215, dest_lon: 31.2755,
      price_rub: 95_000, status: "open", external_hash: "c_corridor", expires_at: 24.hours.from_now
    )

    # Cargo 3: Way off-corridor (Kazan -> Samara) -> should NOT match
    FleetOffer.create!(
      kind: "cargo", body_type: "tent",
      origin_city: "Kazan", origin_lat: 55.7961, origin_lon: 49.1064,
      dest_city: "Samara", dest_lat: 53.1959, dest_lon: 50.1002,
      price_rub: 120_000, status: "open", external_hash: "c_far", expires_at: 24.hours.from_now
    )

    # Cargo 4: Incompatible body type (tral) -> should NOT match
    FleetOffer.create!(
      kind: "cargo", body_type: "tral",
      origin_city: "Moscow", origin_lat: 55.7558, origin_lon: 37.6173,
      dest_city: "Saint Petersburg", dest_lat: 59.9343, dest_lon: 30.3351,
      price_rub: 150_000, status: "open", external_hash: "c_tral", expires_at: 24.hours.from_now
    )

    rows = described_class.call(truck_offer: truck)
    expect(rows.map { |r| r["cargo_id"] }).to eq([ direct.id, corridor.id ])
    expect(rows.first["match_kind"]).to eq("direct")
    expect(rows.first["spread_rub"]).to eq(30_000)
    expect(rows.second["match_kind"]).to eq("corridor_pickup")
    expect(rows.second["detour_km"]).to be <= 90.0
  end
end
