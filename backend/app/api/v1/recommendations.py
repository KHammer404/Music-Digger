"""Recommendation API endpoints."""

from fastapi import APIRouter, Depends, Query

from app.api.v1.deps import get_recommendation_service
from app.services.recommendation_service import RecommendationService

router = APIRouter()


@router.get("/similar-artists")
async def get_similar_artists(
    artist_name: str = Query(..., description="Artist name to find similar artists for"),
    platform: str | None = Query(None, description="Source platform of the artist"),
    platform_id: str | None = Query(None, description="Platform-specific artist ID"),
    limit: int = Query(20, ge=1, le=50),
    service: RecommendationService = Depends(get_recommendation_service),
):
    """Get artists similar to the given artist."""
    results = await service.get_similar_artists(
        artist_name=artist_name,
        platform=platform,
        platform_id=platform_id,
        limit=limit,
    )
    return {
        "artist_name": artist_name,
        "similar_artists": results,
        "total": len(results),
    }


@router.get("/discover")
async def discover(
    seeds: str = Query("", description="Comma-separated seed artist names"),
    limit: int = Query(100, ge=1, le=1000),
    service: RecommendationService = Depends(get_recommendation_service),
):
    """Discover new artists based on seed artists (or trending if no seeds)."""
    seed_list = [s.strip() for s in seeds.split(",") if s.strip()] if seeds else []
    results = await service.get_discovery(
        seed_artist_names=seed_list,
        limit=limit,
    )
    return {
        "seeds": seed_list,
        "discoveries": results,
        "total": len(results),
    }
