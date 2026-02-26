from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


@dataclass
class SourceArtist:
    platform: str
    platform_id: str
    name: str
    url: str | None = None
    image_url: str | None = None
    aliases: list[str] = field(default_factory=list)
    description: str | None = None
    follower_count: int | None = None
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass
class SourceTrack:
    platform: str
    platform_id: str
    title: str
    artist_name: str
    url: str
    duration_seconds: int | None = None
    thumbnail_url: str | None = None
    view_count: int | None = None
    like_count: int | None = None
    release_date: str | None = None
    album_name: str | None = None
    isrc: str | None = None
    is_playable: bool = True
    extra: dict[str, Any] = field(default_factory=dict)


@dataclass
class SourceSearchResult:
    artists: list[SourceArtist] = field(default_factory=list)
    tracks: list[SourceTrack] = field(default_factory=list)


class SourceAdapter(ABC):
    """Abstract base class for all platform source adapters."""

    @property
    @abstractmethod
    def platform_name(self) -> str:
        """Unique platform identifier (e.g., 'youtube', 'spotify')."""
        ...

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Human-readable platform name."""
        ...

    @abstractmethod
    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        """Search for artists on this platform."""
        ...

    @abstractmethod
    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        """Search for tracks on this platform."""
        ...

    @abstractmethod
    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        """Get artist details by platform-specific ID."""
        ...

    @abstractmethod
    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        """Get tracks for an artist on this platform."""
        ...

    async def search(self, query: str, limit: int = 10) -> SourceSearchResult:
        """Convenience method: search for both artists and tracks."""
        artists = await self.search_artists(query, limit=limit)
        tracks = await self.search_tracks(query, limit=limit * 2)
        return SourceSearchResult(artists=artists, tracks=tracks)

    @abstractmethod
    async def is_available(self) -> bool:
        """Check if this source is configured and available."""
        ...
