"""FastAPI application setup."""
from contextlib import asynccontextmanager
from fastapi import FastAPI

from common.logging import setup_logging
from common.redis_client import get_redis, close_redis
from api_server.routes.health import router as health_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    await get_redis()
    yield
    await close_redis()


app = FastAPI(title="GPU Spot Lotto API", version="0.1.0", lifespan=lifespan)

# Health routes (no auth prefix)
app.include_router(health_router)
