"""Bandcamp source adapter — indie/doujin music via web scraping."""

import re

import httpx
from bs4 import BeautifulSoup

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

BANDCAMP_SEARCH = "https://bandcamp.com/search"
SEARCH_CACHE_TTL = 3600
ARTIST_CACHE_TTL = 86400


class BandcampAdapter(SourceAdapter):
    """Bandcamp adapter using web scraping (no official API for search)."""

    def __init__(self):
        self._client = httpx.AsyncClient(
            timeout=15.0,
            headers={"User-Agent": "MusicDigger/0.1.0"},
            follow_redirects=True,
        )

    @property
    def platform_name(self) -> str:
        return "bandcamp"

    @property
    def display_name(self) -> str:
        return "Bandcamp"

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"bc:sa:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        try:
            resp = await self._client.get(BANDCAMP_SEARCH, params={
                "q": query, "item_type": "b", "page": 1,  # b = band/artist
            })
            resp.raise_for_status()
        except httpx.HTTPError:
            return []

        soup = BeautifulSoup(resp.text, "html.parser")
        results = soup.select(".searchresult.band")

        artists = []
        for item in results[:limit]:
            name_el = item.select_one(".heading a")
            img_el = item.select_one(".art img")

            if not name_el:
                continue

            url = name_el.get("href", "").split("?")[0]
            # Extract a stable ID from the URL
            platform_id = re.sub(r'https?://', '', url).rstrip("/")

            artists.append(SourceArtist(
                platform="bandcamp",
                platform_id=platform_id,
                name=name_el.get_text(strip=True),
                url=url,
                image_url=img_el.get("src") if img_el else None,
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"bc:st:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        try:
            resp = await self._client.get(BANDCAMP_SEARCH, params={
                "q": query, "item_type": "t", "page": 1,  # t = track
            })
            resp.raise_for_status()
        except httpx.HTTPError:
            return []

        soup = BeautifulSoup(resp.text, "html.parser")
        results = soup.select(".searchresult.track")

        tracks = []
        for item in results[:limit]:
            heading = item.select_one(".heading a")
            subhead = item.select_one(".subhead")
            img_el = item.select_one(".art img")

            if not heading:
                continue

            url = heading.get("href", "").split("?")[0]
            platform_id = re.sub(r'https?://', '', url).rstrip("/")

            artist_name = ""
            album_name = ""
            if subhead:
                text = subhead.get_text(strip=True)
                # Pattern: "from AlbumName by ArtistName"
                by_match = re.search(r'by\s+(.+)', text)
                from_match = re.search(r'from\s+(.+?)(?:\s+by\s+|$)', text)
                if by_match:
                    artist_name = by_match.group(1).strip()
                if from_match:
                    album_name = from_match.group(1).strip()

            tracks.append(SourceTrack(
                platform="bandcamp",
                platform_id=platform_id,
                title=heading.get_text(strip=True),
                artist_name=artist_name,
                url=url,
                thumbnail_url=img_el.get("src") if img_el else None,
                album_name=album_name,
                is_playable=True,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"bc:a:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        url = f"https://{platform_id}" if not platform_id.startswith("http") else platform_id
        try:
            resp = await self._client.get(url)
            resp.raise_for_status()
        except httpx.HTTPError:
            return None

        soup = BeautifulSoup(resp.text, "html.parser")
        name_el = soup.select_one("#band-name-location .title")
        img_el = soup.select_one("img.band-photo")
        bio_el = soup.select_one(".bio-text")

        artist = SourceArtist(
            platform="bandcamp",
            platform_id=platform_id,
            name=name_el.get_text(strip=True) if name_el else platform_id,
            url=url,
            image_url=img_el.get("src") if img_el else None,
            description=bio_el.get_text(strip=True) if bio_el else None,
        )
        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"bc:at:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        url = f"https://{platform_id}/music" if not platform_id.startswith("http") else f"{platform_id}/music"
        try:
            resp = await self._client.get(url)
            resp.raise_for_status()
        except httpx.HTTPError:
            return []

        soup = BeautifulSoup(resp.text, "html.parser")
        artist = await self.get_artist(platform_id)
        artist_name = artist.name if artist else ""

        items = soup.select(".music-grid-item a")
        tracks = []
        for item in items[:limit]:
            title_el = item.select_one(".title")
            img_el = item.select_one("img")
            href = item.get("href", "")

            if not title_el:
                continue

            base_url = f"https://{platform_id}" if not platform_id.startswith("http") else platform_id
            track_url = f"{base_url}{href}" if href.startswith("/") else href

            tracks.append(SourceTrack(
                platform="bandcamp",
                platform_id=re.sub(r'https?://', '', track_url).rstrip("/"),
                title=title_el.get_text(strip=True),
                artist_name=artist_name,
                url=track_url,
                thumbnail_url=img_el.get("src") if img_el else None,
                is_playable=True,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def is_available(self) -> bool:
        return True
