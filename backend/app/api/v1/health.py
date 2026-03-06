from fastapi import APIRouter

from app.cache.redis_cache import check_redis

router = APIRouter()


@router.get("/health")
async def health_check():
    redis_ok = await check_redis()
    return {
        "status": "healthy",
        "service": "music-digger-api",
        "version": "0.1.0",
        "redis": "connected" if redis_ok else "unavailable (in-memory fallback)",
    }
