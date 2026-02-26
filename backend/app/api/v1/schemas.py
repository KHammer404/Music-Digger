"""Pydantic response schemas for API endpoints."""

from pydantic import BaseModel


class TrackSourceResponse(BaseModel):
    platform: str
    platform_track_id: str
    url: str
    thumbnail_url: str | None = None
    view_count: int | None = None
    like_count: int | None = None
    is_playable: bool = True


class TrackResponse(BaseModel):
    id: str
    title: str
    artist_name: str
    artist_id: str | None = None
    duration_seconds: int | None = None
    thumbnail_url: str | None = None
    release_date: str | None = None
    sources: list[TrackSourceResponse] = []


class ArtistResponse(BaseModel):
    id: str
    name: str
    image_url: str | None = None
    description: str | None = None
    aliases: list[str] = []
    platform_track_counts: dict[str, int] = {}


class SearchResponse(BaseModel):
    query: str
    platforms: list[str]
    artists: list[ArtistResponse]
    tracks: list[TrackResponse]
    total_artists: int
    total_tracks: int


class ArtistDetailResponse(BaseModel):
    artist: ArtistResponse
    tracks: list[TrackResponse]
    total_tracks: int
