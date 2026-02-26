from fastapi import APIRouter, HTTPException, Query

from app.api.v1.schemas import ArtistDetailResponse
from app.services.aggregation_service import source_artist_to_response, source_track_to_response
from app.api.v1.deps import get_aggregation_service

router = APIRouter()


@router.get("/{artist_id}")
async def get_artist(
    artist_id: str,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    """Get artist details and their tracks.

    artist_id format: "platform:platform_id" (e.g., "youtube:UC12345")
    """
    parts = artist_id.split(":", 1)
    if len(parts) != 2:
        raise HTTPException(status_code=400, detail="Invalid artist_id format. Expected 'platform:platform_id'")

    platform, platform_id = parts
    service = get_aggregation_service()

    artist = await service.get_artist(platform, platform_id)
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    all_tracks = await service.get_artist_tracks(platform, platform_id, limit=limit + offset)

    artist_response = source_artist_to_response(artist)
    track_responses = [source_track_to_response(t) for t in all_tracks]
    total = len(track_responses)
    track_responses = track_responses[offset:offset + limit]

    return ArtistDetailResponse(
        artist=artist_response,
        tracks=track_responses,
        total_tracks=total,
    )
