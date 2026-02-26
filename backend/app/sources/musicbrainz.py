"""MusicBrainz source adapter — universal music metadata database."""

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

MB_API = "https://musicbrainz.org/ws/2"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400
HEADERS = {
    "Accept": "application/json",
    "User-Agent": "MusicDigger/0.1.0 (musicdigger@example.com)",
}


class MusicBrainzAdapter(SourceAdapter):
    def __init__(self):
        self._client = httpx.AsyncClient(timeout=15.0, headers=HEADERS)

    @property
    def platform_name(self) -> str:
        return "musicbrainz"

    @property
    def display_name(self) -> str:
        return "MusicBrainz"

    async def _api_get(self, path: str, params: dict | None = None) -> dict | None:
        try:
            resp = await self._client.get(f"{MB_API}/{path}", params=params or {})
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"mb:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_get("artist", {
            "query": query,
            "limit": limit,
            "fmt": "json",
        })
        if not data:
            return []

        artists = []
        for item in data.get("artists", []):
            mbid = item.get("id", "")
            aliases = [a.get("name", "") for a in item.get("aliases", []) if a.get("name")]
            artists.append(SourceArtist(
                platform="musicbrainz",
                platform_id=mbid,
                name=item.get("name", ""),
                url=f"https://musicbrainz.org/artist/{mbid}",
                aliases=aliases,
                description=item.get("disambiguation", ""),
                extra={"score": item.get("score", 0)},
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"mb:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("recording", {
            "query": query,
            "limit": limit,
            "fmt": "json",
        })
        if not data:
            return []

        tracks = []
        for item in data.get("recordings", []):
            rid = item.get("id", "")
            artist_credit = item.get("artist-credit", [])
            artist_name = " & ".join(
                ac.get("name", ac.get("artist", {}).get("name", ""))
                for ac in artist_credit
            ) if artist_credit else ""

            length_ms = item.get("length")
            duration = int(length_ms / 1000) if length_ms else None

            # Get ISRC if available
            isrcs = item.get("isrcs", [])
            isrc = isrcs[0] if isrcs else None

            tracks.append(SourceTrack(
                platform="musicbrainz",
                platform_id=rid,
                title=item.get("title", ""),
                artist_name=artist_name,
                url=f"https://musicbrainz.org/recording/{rid}",
                duration_seconds=duration,
                isrc=isrc,
                is_playable=False,  # MusicBrainz is metadata-only
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"mb:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        data = await self._api_get(f"artist/{platform_id}", {
            "inc": "aliases",
            "fmt": "json",
        })
        if not data:
            return None

        aliases = [a.get("name", "") for a in data.get("aliases", []) if a.get("name")]

        artist = SourceArtist(
            platform="musicbrainz",
            platform_id=platform_id,
            name=data.get("name", ""),
            url=f"https://musicbrainz.org/artist/{platform_id}",
            aliases=aliases,
            description=data.get("disambiguation", ""),
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"mb:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("recording", {
            "query": f"arid:{platform_id}",
            "limit": limit,
            "fmt": "json",
        })
        if not data:
            return []

        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        tracks = []
        for item in data.get("recordings", []):
            rid = item.get("id", "")
            length_ms = item.get("length")
            tracks.append(SourceTrack(
                platform="musicbrainz",
                platform_id=rid,
                title=item.get("title", ""),
                artist_name=artist_name,
                url=f"https://musicbrainz.org/recording/{rid}",
                duration_seconds=int(length_ms / 1000) if length_ms else None,
                is_playable=False,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def is_available(self) -> bool:
        return True
