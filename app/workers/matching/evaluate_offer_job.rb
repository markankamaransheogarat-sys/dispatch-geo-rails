# frozen_string_literal: true

module Matching
  class EvaluateOfferJob
    include Sidekiq::Job

    sidekiq_options queue: :matching, retry: 3

    INSERT_MATCH_SQL = <<~SQL.squish
      INSERT INTO corridor_matches (
        truck_offer_id, cargo_offer_id, match_kind, detour_km, spread_rub, score, status, created_at, updated_at
      )
      VALUES (:truck_id, :cargo_id, :match_kind, :detour_km, :spread_rub, :score, 'pending', NOW(), NOW())
      ON CONFLICT (truck_offer_id, cargo_offer_id) DO NOTHING
      RETURNING id
    SQL

    def perform(truck_offer_id)
      lock_key = "dispatch:lock:offer:#{truck_offer_id}"
      acquired = Sidekiq.redis { |conn| conn.call("SET", lock_key, "1", "NX", "EX", 30) }
      return unless acquired

      truck = FleetOffer.find_by(id: truck_offer_id, kind: "truck", status: "open")
      return unless truck

      candidates = Queries::Geo::FindCorridorMatchesQuery.call(truck_offer: truck)
      candidates.each do |row|
        sql = ActiveRecord::Base.sanitize_sql_array([
          INSERT_MATCH_SQL,
          {
            truck_id: row["truck_id"],
            cargo_id: row["cargo_id"],
            match_kind: row["match_kind"],
            detour_km: row["detour_km"],
            spread_rub: row["spread_rub"],
            score: row["score"]
          }
        ])
        inserted = ActiveRecord::Base.connection.exec_query(sql).first
        Notifications::DispatchMatchJob.perform_async(inserted["id"]) if inserted
      end
    end
  end
end
