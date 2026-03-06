"""Crosslink API — paste any music URL, find it on all platforms."""

from fastapi import APIRouter
from pydantic import BaseModel

from app.api.v1.deps import get_aggregation_service
from app.services.crosslink_service import CrosslinkService

router = APIRouter()


class CrosslinkRequest(BaseModel):
    url: str


@router.post("")
async def crosslink(request: CrosslinkRequest):
    """Find the same track or artist across all 8 platforms.

    Accepts any supported music URL (YouTube, Spotify, NicoNico,
    SoundCloud, Bandcamp) and returns matching results from other platforms.
    """
    service = CrosslinkService(get_aggregation_service())
    return await service.crosslink(request.url)
