from fastapi import APIRouter, Query

from app.api.v1.deps import get_aggregation_service
from app.api.v1.schemas import SearchResponse
from app.services.aggregation_service import source_artist_to_response, source_track_to_response

router = APIRouter()


@router.get("", response_model=SearchResponse)
async def search(
    q: str = Query(..., min_length=1, max_length=200, description="Search query"),
    platforms: str | None = Query(None, description="Comma-separated platform filter (e.g., youtube,spotify)"),
    dedup: bool = Query(True, description="Enable cross-platform deduplication"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
):
    """Search for artists and tracks across all 8 platforms.

    Results are aggregated in parallel, artists are grouped by identity,
    and tracks are deduplicated across platforms.
    """
    platform_list = [p.strip() for p in platforms.split(",") if p.strip()] if platforms else None

    service = get_aggregation_service()

    # Artists: searched and grouped by identity across platforms
    artists = await service.search_artists(q, limit=min(limit, 10), platforms=platform_list)
    artist_responses = [source_artist_to_response(a) for a in artists]

    # Tracks: searched and optionally deduplicated
    if dedup:
        fingerprints = await service.search_tracks_deduped(q, limit=limit + offset, platforms=platform_list)
        dedup_svc = service._dedup
        track_responses = dedup_svc.to_track_responses(fingerprints)
    else:
        tracks = await service.search_tracks(q, limit=limit + offset, platforms=platform_list)
        track_responses = [source_track_to_response(t) for t in tracks]

    # Apply offset
    total_tracks = len(track_responses)
    track_responses = track_responses[offset:offset + limit]

    return SearchResponse(
        query=q,
        platforms=platform_list or [],
        artists=artist_responses,
        tracks=track_responses,
        total_artists=len(artist_responses),
        total_tracks=total_tracks,
    )
