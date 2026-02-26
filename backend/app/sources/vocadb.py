"""VocaDB source adapter — the anchor for doujin/vocaloid artist aliases."""

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

VOCADB_API = "https://vocadb.net/api"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class VocaDBAdapter(SourceAdapter):
    def __init__(self):
        self._client = httpx.AsyncClient(
            timeout=15.0,
            headers={"Accept": "application/json"},
        )

    @property
    def platform_name(self) -> str:
        return "vocadb"

    @property
    def display_name(self) -> str:
        return "VocaDB"

    async def _api_get(self, path: str, params: dict | None = None) -> dict | list | None:
        try:
            resp = await self._client.get(f"{VOCADB_API}/{path}", params=params or {})
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"vocadb:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_get("artists", {
            "query": query,
            "maxResults": limit,
            "nameMatchMode": "Auto",
            "fields": "AdditionalNames,Description,MainPicture",
        })
        if not data or "items" not in data:
            return []

        artists = []
        for item in data["items"]:
            aid = item.get("id", 0)
            names = item.get("additionalNames", "")
            aliases = [n.strip() for n in names.split(",") if n.strip()] if names else []
            img = item.get("mainPicture", {})
            artists.append(SourceArtist(
                platform="vocadb",
                platform_id=str(aid),
                name=item.get("name", ""),
                url=f"https://vocadb.net/Ar/{aid}",
                image_url=img.get("urlOriginal") or img.get("urlThumb"),
                aliases=aliases,
                description=item.get("description", ""),
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"vocadb:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("songs", {
            "query": query,
            "maxResults": limit,
            "nameMatchMode": "Auto",
            "fields": "Artists,ThumbUrl",
            "sort": "FavoritedTimes",
        })
        if not data or "items" not in data:
            return []

        tracks = []
        for item in data["items"]:
            sid = item.get("id", 0)
            artist_str = item.get("artistString", "")
            tracks.append(SourceTrack(
                platform="vocadb",
                platform_id=str(sid),
                title=item.get("name", ""),
                artist_name=artist_str,
                url=f"https://vocadb.net/S/{sid}",
                duration_seconds=item.get("lengthSeconds") or None,
                thumbnail_url=item.get("thumbUrl"),
                release_date=item.get("publishDate", "")[:10] if item.get("publishDate") else None,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"vocadb:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        data = await self._api_get(f"artists/{platform_id}", {
            "fields": "AdditionalNames,Description,MainPicture",
        })
        if not data:
            return None

        names = data.get("additionalNames", "")
        aliases = [n.strip() for n in names.split(",") if n.strip()] if names else []
        img = data.get("mainPicture", {})

        artist = SourceArtist(
            platform="vocadb",
            platform_id=platform_id,
            name=data.get("name", ""),
            url=f"https://vocadb.net/Ar/{platform_id}",
            image_url=img.get("urlOriginal") or img.get("urlThumb"),
            aliases=aliases,
            description=data.get("description", ""),
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"vocadb:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get(f"artists/{platform_id}/songs", {
            "maxResults": limit,
            "fields": "ThumbUrl",
            "sort": "RatingScore",
        })
        if not data or "items" not in data:
            return []

        # Get artist name
        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        tracks = []
        for item in data["items"]:
            sid = item.get("id", 0)
            tracks.append(SourceTrack(
                platform="vocadb",
                platform_id=str(sid),
                title=item.get("name", ""),
                artist_name=item.get("artistString", artist_name),
                url=f"https://vocadb.net/S/{sid}",
                duration_seconds=item.get("lengthSeconds") or None,
                thumbnail_url=item.get("thumbUrl"),
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def is_available(self) -> bool:
        return True  # VocaDB is public, no API key needed

    async def get_artist_aliases(self, platform_id: str) -> list[dict]:
        """Get all aliases for an artist — VocaDB's key strength."""
        data = await self._api_get(f"artists/{platform_id}", {
            "fields": "Names",
        })
        if not data:
            return []

        names = data.get("names", [])
        return [
            {"name": n.get("value", ""), "language": n.get("language", "")}
            for n in names
            if n.get("value")
        ]
