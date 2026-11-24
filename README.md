# Dispatch Geo Rails

Geospatial freight & corridor matching dispatcher built on **Ruby 3.3, Rails 7.2, Grape API, Dry-rb, PostgreSQL (Raw Haversine & Corridor Detour SQL), Redis + Sidekiq, Telegram Bot, and RSpec**.

Inspired by `deadhead-dispatcher` and `outage-sniper`.

## Key Features
- **PostgreSQL Raw Geo-SQL (`Queries::Geo::FindCorridorMatchesQuery`)**: Computes great-circle Haversine leg distances, classifies `direct` vs `corridor_pickup` matches, calculates route detour (`km`) and price spread (`RUB`), and scores candidates inside a single CTE query.
- **Redis + Sidekiq Pipeline**:
  - `Matching::EvaluateOfferJob` uses a Redis distributed lock (`SET ... NX EX 30`) to prevent duplicate concurrent matching.
  - `Notifications::DispatchMatchJob` pushes match alerts to Telegram asynchronously across prioritized queues (`critical`, `matching`, `notifications`).
- **Deadlock-Safe Atomic Booking (`Matches::AcceptMatch`)**: Acquires deterministic row-level `FOR UPDATE` locks on both `FleetOffer` rows in sorted ID order to prevent double-booking races.
- **Dry-rb Validation & Monads**: `Contracts::Offers::CreateContract` + `Offers::IngestOffer`.

## Run Locally
```bash
bin/rails db:prepare
bundle exec rspec --format documentation
bundle exec sidekiq -C config/sidekiq.yml
```
