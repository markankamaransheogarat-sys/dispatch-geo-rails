# frozen_string_literal: true

module Telegram
  class AlertClient
    def initialize(
      bot_token: ENV.fetch("TELEGRAM_BOT_TOKEN", nil),
      chat_id: ENV.fetch("TELEGRAM_DISPATCH_CHAT_ID", nil)
    )
      @bot_token = bot_token
      @chat_id = chat_id
    end

    def notify_match(match)
      return false if @bot_token.blank? || @chat_id.blank?

      truck = match.truck_offer
      cargo = match.cargo_offer
      text = [
        "<b>#{match.match_kind.upcase} MATCH</b> (score: #{match.score})",
        "Truck: #{truck.origin_city} -> #{truck.dest_city} (#{truck.body_type})",
        "Cargo: #{cargo.origin_city} -> #{cargo.dest_city} (#{cargo.body_type})",
        "Detour: #{match.detour_km.round(1)} km | Spread: #{match.spread_rub || 'N/A'} RUB"
      ].join("\n")

      conn = Faraday.new(url: "https://api.telegram.org") do |f|
        f.options.timeout = 3
        f.request :json
      end
      conn.post("/bot#{@bot_token}/sendMessage", { chat_id: @chat_id, text: text, parse_mode: "HTML" }).success?
    rescue Faraday::Error
      false
    end

    def handle_command(text)
      cmd = text.to_s.strip.split(/\s+/).first
      case cmd
      when "/open"
        trucks = FleetOffer.where(kind: "truck", status: "open").count
        cargos = FleetOffer.where(kind: "cargo", status: "open").count
        "Open offers — trucks: #{trucks}, cargos: #{cargos}"
      when "/matches"
        "Total matches: #{CorridorMatch.count} (accepted: #{CorridorMatch.where(status: 'accepted').count})"
      when "/queues"
        stats = Sidekiq::Queue.all.map { |q| "#{q.name}:#{q.size}" }
        "Sidekiq queues: #{stats.empty? ? 'idle' : stats.join(', ')}"
      else
        "Commands: /open, /matches, /queues"
      end
    end
  end
end
