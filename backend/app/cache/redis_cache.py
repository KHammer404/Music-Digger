import json
from typing import Any

import redis.asyncio as redis

from app.config import get_settings

settings = get_settings()

redis_client = redis.from_url(settings.redis_url, decode_responses=True)


async def cache_get(key: str) -> Any | None:
    value = await redis_client.get(key)
    if value is not None:
        return json.loads(value)
    return None


async def cache_set(key: str, value: Any, ttl: int = 3600) -> None:
    await redis_client.set(key, json.dumps(value, default=str), ex=ttl)


async def cache_delete(key: str) -> None:
    await redis_client.delete(key)


async def cache_exists(key: str) -> bool:
    return await redis_client.exists(key) > 0
