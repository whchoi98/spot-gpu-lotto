"""Price Watcher entrypoint — polls Spot prices on interval."""
import asyncio

from common.config import get_settings
from common.logging import setup_logging, get_logger
from common.redis_client import get_redis, close_redis
from price_watcher.collector import collect_all_prices, update_prices

log = get_logger("price_watcher")


async def price_loop(r) -> None:
    """Collect and store Spot prices in a loop."""
    settings = get_settings()
    mock = settings.price_mode == "mock"

    log.info("price_loop_started", mode=settings.price_mode, interval=settings.poll_interval)
    consecutive_errors = 0

    while True:
        try:
            prices = await collect_all_prices(
                settings.regions, settings.instance_types, mock=mock
            )
            count = await update_prices(r, prices)
            consecutive_errors = 0
            log.info("prices_collected", count=count, mock=mock)
        except Exception as e:
            consecutive_errors += 1
            log.error("price_collection_error", error=str(e), consecutive=consecutive_errors)

        await asyncio.sleep(settings.poll_interval)


async def main() -> None:
    setup_logging()
    r = await get_redis()
    log.info("price_watcher_started")

    try:
        await price_loop(r)
    finally:
        await close_redis()


if __name__ == "__main__":
    asyncio.run(main())
