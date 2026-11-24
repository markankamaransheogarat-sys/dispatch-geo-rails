# frozen_string_literal: true

require "digest"

module Offers
  class IngestOffer
    include Dry::Monads[:result, :do]

    def initialize(contract: Contracts::Offers::CreateContract.new)
      @contract = contract
    end

    def call(params)
      validated = yield validate(params)
      ttl_hours = validated.delete(:ttl_hours) || 24

      ext_hash = Digest::SHA256.hexdigest(
        [
          validated[:kind],
          validated[:body_type],
          validated[:origin_city].downcase,
          validated[:dest_city].downcase,
          validated[:price_rub],
          validated[:contact_handle]
        ].join("|")
      )

      existing = FleetOffer.find_by(external_hash: ext_hash)
      return Success(offer: existing, deduplicated: true) if existing

      offer = FleetOffer.create!(
        validated.merge(
          external_hash: ext_hash,
          status: "open",
          expires_at: ttl_hours.hours.from_now
        )
      )

      Matching::EvaluateOfferJob.perform_async(offer.id) if offer.kind == "truck"
      Success(offer: offer, deduplicated: false)
    rescue ActiveRecord::RecordNotUnique
      Success(offer: FleetOffer.find_by!(external_hash: ext_hash), deduplicated: true)
    end

    private

    def validate(params)
      res = @contract.call(params)
      res.success? ? Success(res.to_h) : Failure([ :validation_error, res.errors.to_h ])
    end
  end
end
