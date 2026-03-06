import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.config import get_settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Starting Music Digger API (env=%s)", settings.app_env)

    # Check DB
    try:
        from app.db.session import engine
        async with engine.connect() as conn:
            await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
        logger.info("PostgreSQL connected")
    except Exception as e:
        logger.error("PostgreSQL connection failed: %s", e)
        logger.error("Make sure PostgreSQL is running and DATABASE_URL is correct")

    # Check Redis (optional)
    from app.cache.redis_cache import check_redis
    if await check_redis():
        logger.info("Redis connected")
    else:
        logger.warning("Redis not available - using in-memory cache (data lost on restart)")

    yield

    # Shutdown
    from app.db.session import engine
    await engine.dispose()
    logger.info("Music Digger API stopped")


app = FastAPI(
    title="Music Digger API",
    description="Aggregate music from 8 platforms into a unified view",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)
