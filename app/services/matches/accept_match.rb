# frozen_string_literal: true

module Matches
  class AcceptMatch
    include Dry::Monads[:result]

    def call(match_id:)
      match = CorridorMatch.find_by(id: match_id)
      return Failure([ :not_found, "Match #{match_id} not found" ]) unless match

      ActiveRecord::Base.transaction do
        match.lock!
        return Success(match: match, idempotent_replay: true) if match.status == "accepted"

        # Lock both fleet_offers in deterministic ID order to avoid deadlocks.
        ids = [ match.truck_offer_id, match.cargo_offer_id ].sort
        offers = FleetOffer.where(id: ids).order(:id).lock("FOR UPDATE").index_by(&:id)
        truck = offers.fetch(match.truck_offer_id)
        cargo = offers.fetch(match.cargo_offer_id)

        unless truck.status == "open" && cargo.status == "open"
          return Failure([ :already_booked, "One of the offers is no longer open" ])
        end

        truck.update!(status: "matched")
        cargo.update!(status: "matched")
        match.update!(status: "accepted")
      end

      Success(match: match.reload, idempotent_replay: false)
    end
  end
end
