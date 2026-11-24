# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dispatch Geo API + Sidekiq + Redis", type: :request do
  it "checks PostgreSQL and Redis health" do
    get "/api/v1/health"
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json["db"]).to eq("postgresql")
    expect(json["redis"]).to eq("PONG")
  end

  it "ingests offers, executes Sidekiq geo-matching pipeline with Redis lock, and accepts match atomically" do
    Sidekiq::Testing.inline! do
      post "/api/v1/offers",
           params: {
             kind: "cargo", body_type: "tent",
             origin_city: "Moscow", origin_lat: 55.7558, origin_lon: 37.6173,
             dest_city: "Tula", dest_lat: 54.1961, dest_lon: 37.6182,
             price_rub: 45_000, contact_handle: "@cargo_owner"
           }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:created)

      post "/api/v1/offers",
           params: {
             kind: "truck", body_type: "ref",
             origin_city: "Podolsk", origin_lat: 55.4312, origin_lon: 37.5447,
             dest_city: "Tula", dest_lat: 54.1961, dest_lon: 37.6182,
             price_rub: 30_000, contact_handle: "@truck_driver"
           }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
      expect(response).to have_http_status(:created)
      truck_id = JSON.parse(response.body).dig("offer", "id")

      get "/api/v1/offers/#{truck_id}/matches"
      expect(response).to have_http_status(:ok)
      matches = JSON.parse(response.body)["matches"]
      expect(matches.size).to eq(1)
      expect(matches.first["status"]).to eq("notified")
      match_id = matches.first["id"]

      post "/api/v1/matches/#{match_id}/accept"
      expect(response).to have_http_status(:created).or have_http_status(:ok)
      expect(JSON.parse(response.body).dig("match", "status")).to eq("accepted")

      # Second accept is idempotent
      post "/api/v1/matches/#{match_id}/accept"
      expect(JSON.parse(response.body)["idempotent_replay"]).to be(true)
    end
  end

  it "responds to Telegram /open and /queues commands" do
    post "/api/v1/webhooks/telegram",
         params: { message: { text: "/open" } }.to_json,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "X-Telegram-Bot-Api-Secret-Token" => "dev-dispatch-tg-secret"
         }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["reply"]).to include("Open offers")
  end
end
