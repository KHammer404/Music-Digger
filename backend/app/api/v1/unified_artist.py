"""Unified Artist API — aggregated artist profile across all platforms."""

import asyncio
import logging

from fastapi import APIRouter, Query

from app.api.v1.deps import get_aggregation_service
from app.cache.redis_cache import cache_get, cache_set
from app.services.aggregation_service import source_track_to_response

router = APIRouter()

logger = logging.getLogger(__name__)

UNIFIED_CACHE_TTL = 86400  # 24 hours


@router.get("/unified/{platform}:{platform_id}")
async def unified_artist(
    platform: str,
    platform_id: str,
    track_limit: int = Query(50, ge=1, le=200),
):
    """Get a unified artist profile aggregated across all platforms.

    Combines artist info, aliases, and tracks from every platform
    where this artist exists, with cross-platform deduplication.
    """
    cache_key = f"unified_artist:{platform}:{platform_id}:{track_limit}"
    cached = await cache_get(cache_key)
    if cached is not None:
        return cached

    service = get_aggregation_service()

    # 1. Get artist from specified platform
    artist = await service.get_artist(platform, platform_id)
    if artist is None:
        return {"error": "Artist not found", "platform": platform, "platform_id": platform_id}

    # 2. Search all platforms by name + aliases
    search_names = [artist.name] + artist.aliases[:5]  # limit alias count
    all_artists = []
    for name in search_names[:3]:  # search with top 3 names
        found = await service.search_artists(name, limit=10)
        all_artists.extend(found)

    # 3. Collect platform presences (from merged artist groups)
    platforms = []
    seen_platform_ids = set()
    # Add the original
    seen_platform_ids.add((platform, platform_id))
    platforms.append({
        "platform": platform,
        "platform_id": platform_id,
        "name": artist.name,
        "url": artist.url,
        "image_url": artist.image_url,
        "follower_count": artist.follower_count,
    })

    # Add from search results
    for found_artist in all_artists:
        platform_map = found_artist.extra.get("platforms", {}) if found_artist.extra else {}
        if platform_map:
            for p, pid in platform_map.items():
                if (p, pid) not in seen_platform_ids:
                    seen_platform_ids.add((p, pid))
                    platforms.append({
                        "platform": p,
                        "platform_id": pid,
                        "name": found_artist.name,
                        "url": found_artist.url if p == found_artist.platform else None,
                        "image_url": found_artist.image_url,
                        "follower_count": found_artist.follower_count if p == found_artist.platform else None,
                    })
        elif (found_artist.platform, found_artist.platform_id) not in seen_platform_ids:
            seen_platform_ids.add((found_artist.platform, found_artist.platform_id))
            platforms.append({
                "platform": found_artist.platform,
                "platform_id": found_artist.platform_id,
                "name": found_artist.name,
                "url": found_artist.url,
                "image_url": found_artist.image_url,
                "follower_count": found_artist.follower_count,
            })

    # 4. Collect all aliases
    all_aliases = set(artist.aliases)
    for found_artist in all_artists:
        all_aliases.add(found_artist.name)
        all_aliases.update(found_artist.aliases)
    all_aliases.discard(artist.name)

    # 5. Fetch tracks from all matched platforms in parallel
    track_tasks = []
    for plat in platforms[:8]:  # limit to 8 platforms
        track_tasks.append(
            service.get_artist_tracks(plat["platform"], plat["platform_id"], limit=track_limit)
        )
    track_results = await asyncio.gather(*track_tasks, return_exceptions=True)

    all_tracks = []
    for result in track_results:
        if isinstance(result, list):
            all_tracks.extend(result)

    # 6. Deduplicate tracks
    dedup = service._dedup
    fingerprints = dedup.deduplicate(all_tracks)
    track_responses = dedup.to_track_responses(fingerprints[:track_limit])

    # Pick best image
    image_url = artist.image_url
    if not image_url:
        for plat in platforms:
            if plat.get("image_url"):
                image_url = plat["image_url"]
                break

    result = {
        "name": artist.name,
        "aliases": list(all_aliases),
        "image_url": image_url,
        "description": artist.description,
        "platforms": platforms,
        "tracks": track_responses,
        "total_tracks": len(fingerprints),
    }

    await cache_set(cache_key, result, UNIFIED_CACHE_TTL)
    return result
