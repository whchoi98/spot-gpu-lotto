"""FastAPI application setup."""
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.responses import PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from api_server.auth import CurrentUser, get_current_user
from api_server.routes.admin import router as admin_router
from api_server.routes.agent import router as agent_router
from api_server.routes.health import router as health_router
from api_server.routes.jobs import router as jobs_router
from api_server.routes.prices import router as prices_router
from api_server.routes.templates import router as templates_router
from api_server.routes.upload import router as upload_router
from common.logging import setup_logging
from common.redis_client import close_redis, get_redis


@asynccontextmanager
async def lifespan(app: FastAPI):
    setup_logging()
    await get_redis()
    yield
    await close_redis()


app = FastAPI(title="GPU Spot Lotto API", version="0.1.0", lifespan=lifespan)

# Health routes (no auth prefix)
app.include_router(health_router)
app.include_router(prices_router)
# Jobs routes
app.include_router(jobs_router)
app.include_router(upload_router)
app.include_router(templates_router)
app.include_router(admin_router)
app.include_router(agent_router)


@app.get("/api/me")
async def get_me(user: CurrentUser = Depends(get_current_user)):
    """Return current user info (from ALB JWT or dev fallback)."""
    return {"user_id": user.user_id, "role": user.role}


@app.get("/metrics")
async def metrics():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)
