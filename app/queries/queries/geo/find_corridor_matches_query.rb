# frozen_string_literal: true

module Queries
  module Geo
    class FindCorridorMatchesQuery
      # Pure PostgreSQL Haversine + route corridor detour calculation.
      # Detour = (truck_origin -> cargo_origin) + (cargo_origin -> cargo_dest) + (cargo_dest -> truck_dest) - (truck_origin -> truck_dest)
      SQL = <<~SQL.squish
        WITH truck AS (
          SELECT
            id AS truck_id,
            origin_lat AS t_olat,
            origin_lon AS t_olon,
            dest_lat AS t_dlat,
            dest_lon AS t_dlon,
            price_rub AS t_price,
            6371.0 * 2.0 * ASIN(SQRT(
              POWER(SIN(RADIANS(dest_lat - origin_lat) / 2.0), 2) +
              COS(RADIANS(origin_lat)) * COS(RADIANS(dest_lat)) *
              POWER(SIN(RADIANS(dest_lon - origin_lon) / 2.0), 2)
            )) AS truck_direct_km
          FROM fleet_offers
          WHERE id = :truck_id AND kind = 'truck' AND status = 'open'
        ),
        distances AS (
          SELECT
            t.truck_id,
            c.id AS cargo_id,
            t.t_price,
            c.price_rub AS c_price,
            t.truck_direct_km,
            6371.0 * 2.0 * ASIN(SQRT(
              POWER(SIN(RADIANS(c.origin_lat - t.t_olat) / 2.0), 2) +
              COS(RADIANS(t.t_olat)) * COS(RADIANS(c.origin_lat)) *
              POWER(SIN(RADIANS(c.origin_lon - t.t_olon) / 2.0), 2)
            )) AS leg_to_pickup_km,
            6371.0 * 2.0 * ASIN(SQRT(
              POWER(SIN(RADIANS(c.dest_lat - c.origin_lat) / 2.0), 2) +
              COS(RADIANS(c.origin_lat)) * COS(RADIANS(c.dest_lat)) *
              POWER(SIN(RADIANS(c.dest_lon - c.origin_lon) / 2.0), 2)
            )) AS cargo_route_km,
            6371.0 * 2.0 * ASIN(SQRT(
              POWER(SIN(RADIANS(t.t_dlat - c.dest_lat) / 2.0), 2) +
              COS(RADIANS(c.dest_lat)) * COS(RADIANS(t.t_dlat)) *
              POWER(SIN(RADIANS(t.t_dlon - c.dest_lon) / 2.0), 2)
            )) AS leg_to_dest_km
          FROM truck t
          INNER JOIN fleet_offers c
            ON c.kind = 'cargo'
           AND c.status = 'open'
           AND c.expires_at > NOW()
           AND c.body_type = ANY(:compatible_bodies)
        ),
        scored AS (
          SELECT
            truck_id,
            cargo_id,
            GREATEST(0.0, (leg_to_pickup_km + cargo_route_km + leg_to_dest_km) - truck_direct_km) AS detour_km,
            CASE
              WHEN leg_to_pickup_km <= :direct_radius_km AND leg_to_dest_km <= :direct_radius_km THEN 'direct'
              ELSE 'corridor_pickup'
            END AS match_kind,
            CASE
              WHEN c_price IS NOT NULL AND t_price IS NOT NULL THEN (c_price - t_price)
              ELSE NULL
            END AS spread_rub,
            ROUND(
              (
                CASE WHEN leg_to_pickup_km <= :direct_radius_km AND leg_to_dest_km <= :direct_radius_km THEN 100.0 ELSE 60.0 END
                + COALESCE((c_price - t_price) / 1000.0, 0.0)
                - (GREATEST(0.0, (leg_to_pickup_km + cargo_route_km + leg_to_dest_km) - truck_direct_km) * 0.5)
              )::numeric,
              2
            )::double precision AS score
          FROM distances
          WHERE (
            (leg_to_pickup_km <= :direct_radius_km AND leg_to_dest_km <= :direct_radius_km)
            OR GREATEST(0.0, (leg_to_pickup_km + cargo_route_km + leg_to_dest_km) - truck_direct_km) <= :max_detour_km
          )
        )
        SELECT *
        FROM scored
        ORDER BY score DESC
        LIMIT :limit
      SQL

      def self.call(truck_offer:, direct_radius_km: 75.0, max_detour_km: 90.0, limit: 20)
        bodies = "{#{truck_offer.compatible_cargo_bodies.join(',')}}"
        sql = ActiveRecord::Base.sanitize_sql_array([
          SQL,
          {
            truck_id: truck_offer.id,
            compatible_bodies: bodies,
            direct_radius_km: direct_radius_km,
            max_detour_km: max_detour_km,
            limit: limit
          }
        ])

        ActiveRecord::Base.connection.exec_query(sql).to_a
      end
    end
  end
end
