# frozen_string_literal: true

module Notifications
  class DispatchMatchJob
    include Sidekiq::Job

    sidekiq_options queue: :notifications, retry: 5

    def perform(match_id)
      match = CorridorMatch.includes(:truck_offer, :cargo_offer).find_by(id: match_id)
      return unless match && match.status == "pending"

      Telegram::AlertClient.new.notify_match(match)
      match.update!(status: "notified", notified_at: Time.current)
    end
  end
end
