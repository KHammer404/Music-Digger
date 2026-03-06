import json
import time
import logging
from typing import Any

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

# --- In-memory fallback cache ---
_memory_cache: dict[str, tuple[str, float]] = {}  # key -> (json_value, expires_at)


def _mem_cleanup() -> None:
    """Remove expired entries (lazy, runs occasionally)."""
    now = time.time()
    expired = [k for k, (_, exp) in _memory_cache.items() if exp <= now]
    for k in expired:
        del _memory_cache[k]


def _mem_get(key: str) -> Any | None:
    entry = _memory_cache.get(key)
    if entry is None:
        return None
    value, expires_at = entry
    if time.time() >= expires_at:
        del _memory_cache[key]
        return None
    return json.loads(value)


def _mem_set(key: str, value: Any, ttl: int = 3600) -> None:
    if len(_memory_cache) > 5000:
        _mem_cleanup()
    _memory_cache[key] = (json.dumps(value, default=str), time.time() + ttl)


def _mem_delete(key: str) -> None:
    _memory_cache.pop(key, None)


def _mem_exists(key: str) -> bool:
    entry = _memory_cache.get(key)
    if entry is None:
        return False
    if time.time() >= entry[1]:
        del _memory_cache[key]
        return False
    return True


# --- Redis client (lazy init) ---
_redis_client = None
_redis_available = None  # None = not checked yet


async def _get_redis():
    global _redis_client, _redis_available

    if _redis_available is False:
        return None

    if _redis_client is None:
        try:
            import redis.asyncio as redis
            _redis_client = redis.from_url(settings.redis_url, decode_responses=True)
            await _redis_client.ping()
            _redis_available = True
            logger.info("Redis connected: %s", settings.redis_url)
        except Exception:
            _redis_client = None
            _redis_available = False
            logger.warning("Redis unavailable, using in-memory cache")
            return None

    return _redis_client


# --- Public API (same interface, auto fallback) ---

async def cache_get(key: str) -> Any | None:
    client = await _get_redis()
    if client is None:
        return _mem_get(key)
    try:
        value = await client.get(key)
        if value is not None:
            return json.loads(value)
        return None
    except Exception:
        return _mem_get(key)


async def cache_set(key: str, value: Any, ttl: int = 3600) -> None:
    client = await _get_redis()
    if client is None:
        _mem_set(key, value, ttl)
        return
    try:
        await client.set(key, json.dumps(value, default=str), ex=ttl)
    except Exception:
        _mem_set(key, value, ttl)


async def cache_delete(key: str) -> None:
    client = await _get_redis()
    if client is None:
        _mem_delete(key)
        return
    try:
        await client.delete(key)
    except Exception:
        _mem_delete(key)


async def cache_exists(key: str) -> bool:
    client = await _get_redis()
    if client is None:
        return _mem_exists(key)
    try:
        return await client.exists(key) > 0
    except Exception:
        return _mem_exists(key)


async def check_redis() -> bool:
    """Check if Redis is reachable. Used by health endpoint."""
    client = await _get_redis()
    return client is not None
