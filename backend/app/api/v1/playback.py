import logging

from fastapi import APIRouter, HTTPException

from app.api.v1.deps import get_aggregation_service
from app.services.playback_resolver import PlaybackResolverService
from app.sources.bandcamp import BandcampAdapter
from app.sources.soundcloud import SoundCloudAdapter

logger = logging.getLogger(__name__)

router = APIRouter()

_resolver = PlaybackResolverService()


@router.get("/{platform}/{track_id:path}")
async def get_playback_info(platform: str, track_id: str):
    """Get playback info for a specific track on a specific platform.

    Returns the engine type, URLs, and whether authentication is required.
    For SoundCloud/Bandcamp, resolves the actual audio stream URL.
    """
    service = get_aggregation_service()

    # Find the adapter for this platform
    adapter = None
    for a in service._adapters:
        if a.platform_name == platform:
            adapter = a
            break

    if not adapter:
        raise HTTPException(status_code=400, detail=f"Unknown platform: {platform}")

    # Create a minimal source track from the ID
    from app.sources.base import SourceTrack
    source = SourceTrack(
        platform=platform,
        platform_id=track_id,
        title="",
        artist_name="",
        url=_build_url(platform, track_id),
        is_playable=True,
    )

    info = _resolver.resolve(source)

    # Resolve actual stream URLs for supported platforms
    stream_url = None
    if isinstance(adapter, SoundCloudAdapter):
        stream_url = await adapter.get_stream_url(track_id)
    elif isinstance(adapter, BandcampAdapter):
        stream_url = await adapter.get_stream_url(track_id)

    if stream_url:
        info.stream_url = stream_url
        logger.info("Resolved stream URL for %s/%s", platform, track_id)
    else:
        logger.warning("Failed to resolve stream URL for %s/%s", platform, track_id)

    return {
        "platform": info.platform,
        "track_id": info.track_id,
        "url": info.url,
        "stream_url": info.stream_url,
        "preview_url": info.preview_url,
        "engine": info.engine,
        "is_playable": info.is_playable,
        "requires_auth": info.requires_auth,
    }


def _build_url(platform: str, track_id: str) -> str:
    urls = {
        "youtube": f"https://www.youtube.com/watch?v={track_id}",
        "spotify": f"https://open.spotify.com/track/{track_id}",
        "niconico": f"https://www.nicovideo.jp/watch/{track_id}",
        "soundcloud": f"https://soundcloud.com/{track_id}",
        "bandcamp": f"https://{track_id}",
    }
    return urls.get(platform, "")
