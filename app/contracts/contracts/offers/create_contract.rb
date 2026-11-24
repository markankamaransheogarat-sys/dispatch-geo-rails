# frozen_string_literal: true

module Contracts
  module Offers
    class CreateContract < Dry::Validation::Contract
      params do
        required(:kind).filled(:string, included_in?: FleetOffer::KINDS)
        required(:body_type).filled(:string, included_in?: FleetOffer::COMPATIBLE_BODIES.keys)
        required(:origin_city).filled(:string, max_size?: 80)
        required(:origin_lat).filled(:float, gteq?: -90.0, lteq?: 90.0)
        required(:origin_lon).filled(:float, gteq?: -180.0, lteq?: 180.0)
        required(:dest_city).filled(:string, max_size?: 80)
        required(:dest_lat).filled(:float, gteq?: -90.0, lteq?: 90.0)
        required(:dest_lon).filled(:float, gteq?: -180.0, lteq?: 180.0)
        optional(:price_rub).maybe(:integer, gt?: 0)
        optional(:source_chat).maybe(:string, max_size?: 120)
        optional(:contact_handle).maybe(:string, max_size?: 80)
        optional(:ttl_hours).filled(:integer, gt?: 0, lteq?: 168)
      end
    end
  end
end
