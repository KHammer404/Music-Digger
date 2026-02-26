"""Spotify source adapter — rich metadata + ISRC codes."""

import base64

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.config import get_settings
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

settings = get_settings()

SPOTIFY_AUTH_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_API = "https://api.spotify.com/v1"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400
TOKEN_CACHE_TTL = 3500  # slightly less than 1 hour


class SpotifyAdapter(SourceAdapter):
    def __init__(self):
        self._client_id = settings.spotify_client_id
        self._client_secret = settings.spotify_client_secret
        self._client = httpx.AsyncClient(timeout=15.0)

    @property
    def platform_name(self) -> str:
        return "spotify"

    @property
    def display_name(self) -> str:
        return "Spotify"

    async def _get_token(self) -> str | None:
        cached = await cache_get("spotify:token")
        if cached:
            return cached

        if not self._client_id or not self._client_secret:
            return None

        auth_str = base64.b64encode(
            f"{self._client_id}:{self._client_secret}".encode()
        ).decode()

        try:
            resp = await self._client.post(
                SPOTIFY_AUTH_URL,
                headers={"Authorization": f"Basic {auth_str}"},
                data={"grant_type": "client_credentials"},
            )
            resp.raise_for_status()
            token = resp.json().get("access_token")
            if token:
                await cache_set("spotify:token", token, TOKEN_CACHE_TTL)
            return token
        except httpx.HTTPError:
            return None

    async def _api_get(self, path: str, params: dict | None = None) -> dict | None:
        token = await self._get_token()
        if not token:
            return None
        try:
            resp = await self._client.get(
                f"{SPOTIFY_API}/{path}",
                params=params or {},
                headers={"Authorization": f"Bearer {token}"},
            )
            resp.raise_for_status()
            return resp.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"sp:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_get("search", {
            "q": query, "type": "artist", "limit": limit,
        })
        if not data:
            return []

        artists = []
        for item in data.get("artists", {}).get("items", []):
            images = item.get("images", [])
            artists.append(SourceArtist(
                platform="spotify",
                platform_id=item.get("id", ""),
                name=item.get("name", ""),
                url=item.get("external_urls", {}).get("spotify"),
                image_url=images[0]["url"] if images else None,
                follower_count=item.get("followers", {}).get("total"),
                extra={"genres": item.get("genres", []), "popularity": item.get("popularity", 0)},
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"sp:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_get("search", {
            "q": query, "type": "track", "limit": limit,
        })
        if not data:
            return []

        tracks = []
        for item in data.get("tracks", {}).get("items", []):
            artists = item.get("artists", [])
            artist_name = ", ".join(a.get("name", "") for a in artists)
            album = item.get("album", {})
            images = album.get("images", [])
            isrc = item.get("external_ids", {}).get("isrc")
            preview = item.get("preview_url")

            tracks.append(SourceTrack(
                platform="spotify",
                platform_id=item.get("id", ""),
                title=item.get("name", ""),
                artist_name=artist_name,
                url=item.get("external_urls", {}).get("spotify", ""),
                duration_seconds=item.get("duration_ms", 0) // 1000 if item.get("duration_ms") else None,
                thumbnail_url=images[0]["url"] if images else None,
                release_date=album.get("release_date"),
                album_name=album.get("name"),
                isrc=isrc,
                is_playable=preview is not None,
                extra={"preview_url": preview, "popularity": item.get("popularity", 0)},
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"sp:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        data = await self._api_get(f"artists/{platform_id}")
        if not data:
            return None

        images = data.get("images", [])
        artist = SourceArtist(
            platform="spotify",
            platform_id=platform_id,
            name=data.get("name", ""),
            url=data.get("external_urls", {}).get("spotify"),
            image_url=images[0]["url"] if images else None,
            follower_count=data.get("followers", {}).get("total"),
            extra={"genres": data.get("genres", []), "popularity": data.get("popularity", 0)},
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"sp:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        # Get top tracks
        data = await self._api_get(f"artists/{platform_id}/top-tracks")
        tracks_data = data.get("tracks", []) if data else []

        # Also get albums → tracks for more complete listing
        albums_data = await self._api_get(f"artists/{platform_id}/albums", {
            "limit": 50, "include_groups": "album,single",
        })

        album_ids = [a["id"] for a in (albums_data or {}).get("items", [])[:20]]
        for album_id in album_ids:
            album_tracks = await self._api_get(f"albums/{album_id}/tracks", {"limit": 50})
            if album_tracks:
                tracks_data.extend(album_tracks.get("items", []))
            if len(tracks_data) >= limit:
                break

        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        seen_ids = set()
        tracks = []
        for item in tracks_data[:limit]:
            tid = item.get("id", "")
            if tid in seen_ids:
                continue
            seen_ids.add(tid)

            item_artists = item.get("artists", [])
            aname = ", ".join(a.get("name", "") for a in item_artists) if item_artists else artist_name
            preview = item.get("preview_url")

            tracks.append(SourceTrack(
                platform="spotify",
                platform_id=tid,
                title=item.get("name", ""),
                artist_name=aname,
                url=item.get("external_urls", {}).get("spotify", ""),
                duration_seconds=item.get("duration_ms", 0) // 1000 if item.get("duration_ms") else None,
                is_playable=preview is not None,
                extra={"preview_url": preview},
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def is_available(self) -> bool:
        return bool(self._client_id and self._client_secret)
