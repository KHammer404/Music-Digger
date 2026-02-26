from fastapi import APIRouter, HTTPException

from app.api.v1.deps import get_aggregation_service
from app.services.playback_resolver import PlaybackResolverService

router = APIRouter()

_resolver = PlaybackResolverService()


@router.get("/{platform}/{track_id}")
async def get_playback_info(platform: str, track_id: str):
    """Get playback info for a specific track on a specific platform.

    Returns the engine type, URLs, and whether authentication is required.
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

    # Search for the specific track
    tracks = await adapter.search_tracks(track_id, limit=1)
    if not tracks:
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
    else:
        source = tracks[0]

    info = _resolver.resolve(source)

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
