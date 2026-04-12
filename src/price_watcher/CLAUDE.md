# Price Watcher Module

## Role
Periodically polls EC2 Spot price API across configured regions and stores
prices in Redis sorted set for the dispatcher and API to consume.

## Key Files
- `main.py` -- Entry point, polling loop, Redis write
- `collector.py` -- `collect_prices()` calls EC2 `describe_spot_price_history()`

## Rules
- Poll interval configured via `POLL_INTERVAL` env var (default 30s in dev)
- Price mode: `live` calls real EC2 API, `mock` uses static test data
- Sorted set key format: `{region}:{instance_type}`, score = price (float)
- Old prices are replaced atomically (ZADD with GT flag)
