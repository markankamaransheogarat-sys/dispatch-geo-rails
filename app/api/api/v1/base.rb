# frozen_string_literal: true

module Api
  module V1
    class Base < Grape::API
      version "v1", using: :path
      format :json
      prefix :api

      get :health do
        ActiveRecord::Base.connection.execute("SELECT 1")
        redis_pong = Sidekiq.redis(&:ping)
        { status: "ok", db: "postgresql", redis: redis_pong }
      end

      resource :offers do
        post do
          result = ::Offers::IngestOffer.new.call(params.to_h.deep_symbolize_keys)
          if result.success?
            data = result.value!
            status(data[:deduplicated] ? 200 : 201)
            {
              deduplicated: data[:deduplicated],
              offer: data[:offer].as_json
            }
          else
            code, details = result.failure
            error!({ error: code, details: details }, 422)
          end
        end

        get ":id/matches" do
          offer = FleetOffer.find_by(id: params[:id])
          error!({ error: "not_found" }, 404) unless offer

          matches = CorridorMatch.where(truck_offer_id: offer.id).order(score: :desc)
          { offer_id: offer.id, matches: matches.as_json }
        end
      end

      resource :matches do
        post ":id/accept" do
          result = ::Matches::AcceptMatch.new.call(match_id: params[:id])
          if result.success?
            status 200
            data = result.value!
            { idempotent_replay: data[:idempotent_replay], match: data[:match].as_json }
          else
            code, details = result.failure
            error!({ error: code, details: details }, code == :not_found ? 404 : 409)
          end
        end
      end

      resource :webhooks do
        post :telegram do
          expected = ENV.fetch("TELEGRAM_WEBHOOK_SECRET", "dev-dispatch-tg-secret")
          secret = headers["X-Telegram-Bot-Api-Secret-Token"] || headers["x-telegram-bot-api-secret-token"]
          unless secret.to_s.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(secret.to_s, expected)
            error!({ error: "unauthorized" }, 401)
          end

          status 200
          reply = ::Telegram::AlertClient.new.handle_command(params.dig(:message, :text))
          { reply: reply }
        end
      end
    end
  end
end
