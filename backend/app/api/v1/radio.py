"""Rabbit Hole Radio API — endless cross-platform music discovery."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.api.v1.deps import get_aggregation_service, get_recommendation_service
from app.services.radio_service import RadioService

router = APIRouter()


class RadioNextRequest(BaseModel):
    current_artist_name: str
    played_artist_names: list[str] = []
    played_platforms: list[str] = []


@router.post("/next")
async def radio_next(request: RadioNextRequest):
    """Get the next track for rabbit hole radio.

    Takes the current artist and play history, returns a track from
    a similar artist on a different platform when possible.
    """
    service = RadioService(
        recommendation=get_recommendation_service(),
        aggregation=get_aggregation_service(),
    )

    result = await service.get_next_track(
        current_artist_name=request.current_artist_name,
        played_artist_names=request.played_artist_names,
        played_platforms=request.played_platforms,
    )

    if result is None:
        return {"error": "No suitable next track found", "track": None}

    return result
