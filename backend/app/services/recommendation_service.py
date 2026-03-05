"""Recommendation service — similar artists and personalized discovery."""

import asyncio

from app.cache.redis_cache import cache_get, cache_set
from app.matching.name_normalizer import normalize_name
from app.sources.base import SourceArtist
from app.sources.lastfm import LastfmAdapter
from app.sources.spotify import SpotifyAdapter
from app.sources.vocadb import VocaDBAdapter
from app.sources.youtube import YouTubeAdapter

SIMILAR_CACHE_TTL = 86400  # 24 hours
DISCOVER_CACHE_TTL = 3600  # 1 hour

# Last.fm returns this placeholder for all artists (no real images anymore)
LASTFM_PLACEHOLDER = "2a96cbd8b46e442fc41c2b86b821562f"


def _is_real_image(url: str | None) -> bool:
    """Check if an image URL is a real image (not a Last.fm placeholder)."""
    if not url:
        return False
    return LASTFM_PLACEHOLDER not in url


class RecommendationService:
    """Combines Last.fm, Spotify, and VocaDB data for artist recommendations."""

    def __init__(
        self,
        lastfm: LastfmAdapter,
        spotify: SpotifyAdapter,
        vocadb: VocaDBAdapter,
        youtube: YouTubeAdapter | None = None,
    ):
        self._lastfm = lastfm
        self._spotify = spotify
        self._vocadb = vocadb
        self._youtube = youtube

    async def get_similar_artists(
        self,
        artist_name: str,
        platform: str | None = None,
        platform_id: str | None = None,
        limit: int = 20,
    ) -> list[dict]:
        """Get similar artists by combining Last.fm + Spotify recommendations."""
        cache_key = f"rec:similar:{normalize_name(artist_name)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached[:limit]

        tasks = []

        # Last.fm similar artists (primary source)
        if platform == "lastfm" and platform_id:
            tasks.append(self._lastfm.get_similar_artists(platform_id, limit=limit))
        else:
            tasks.append(self._lastfm_similar_by_name(artist_name, limit))

        # Spotify related artists
        if platform == "spotify" and platform_id:
            tasks.append(self._spotify_related(platform_id))
        else:
            tasks.append(self._spotify_related_by_name(artist_name))

        results = await asyncio.gather(*tasks, return_exceptions=True)

        seen_names: dict[str, dict] = {}
        for result in results:
            if isinstance(result, list):
                for artist in result:
                    if isinstance(artist, SourceArtist):
                        normalized = normalize_name(artist.name)
                        if normalized and normalized not in seen_names:
                            match_score = artist.extra.get("match", 0) if artist.extra else 0
                            seen_names[normalized] = {
                                "name": artist.name,
                                "image_url": artist.image_url if _is_real_image(artist.image_url) else None,
                                "platform": artist.platform,
                                "platform_id": artist.platform_id,
                                "url": artist.url,
                                "match_score": float(match_score),
                            }
                    elif isinstance(artist, dict):
                        name = artist.get("name", "")
                        normalized = normalize_name(name)
                        if normalized and normalized not in seen_names:
                            seen_names[normalized] = artist

        # Remove the query artist itself
        query_normalized = normalize_name(artist_name)
        seen_names.pop(query_normalized, None)

        # Sort by match score descending
        recommendations = sorted(
            seen_names.values(),
            key=lambda x: x.get("match_score", 0),
            reverse=True,
        )[:limit]

        await cache_set(cache_key, recommendations, SIMILAR_CACHE_TTL)
        return recommendations

    async def get_discovery(
        self,
        seed_artist_names: list[str],
        limit: int = 30,
    ) -> list[dict]:
        """Discover new artists based on multiple seed artists (for home screen)."""
        if not seed_artist_names:
            return await self._get_trending()

        cache_parts = ":".join(normalize_name(n) for n in seed_artist_names[:5])
        cache_key = f"rec:discover:{cache_parts}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached[:limit]

        # Get similar artists for each seed
        tasks = [
            self.get_similar_artists(name, limit=10)
            for name in seed_artist_names[:5]
        ]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Score artists by frequency across seeds
        artist_scores: dict[str, dict] = {}
        seed_normalized = {normalize_name(n) for n in seed_artist_names}

        for result in results:
            if not isinstance(result, list):
                continue
            for i, artist in enumerate(result):
                name = artist.get("name", "")
                normalized = normalize_name(name)

                # Skip seed artists
                if normalized in seed_normalized:
                    continue

                if normalized not in artist_scores:
                    artist_scores[normalized] = {
                        **artist,
                        "discovery_score": 0.0,
                        "seed_count": 0,
                    }

                # Higher rank = higher score; appearing in multiple seeds = bonus
                rank_score = max(0, 1.0 - i * 0.1)
                artist_scores[normalized]["discovery_score"] += rank_score
                artist_scores[normalized]["seed_count"] += 1
                # Keep best image
                if artist.get("image_url") and not artist_scores[normalized].get("image_url"):
                    artist_scores[normalized]["image_url"] = artist["image_url"]

        # Sort by discovery score
        discoveries = sorted(
            artist_scores.values(),
            key=lambda x: x.get("discovery_score", 0),
            reverse=True,
        )[:limit]

        await cache_set(cache_key, discoveries, DISCOVER_CACHE_TTL)
        return discoveries

    async def _get_trending(self, limit: int = 100) -> list[dict]:
        """Fallback: get trending/popular artists from Last.fm charts."""
        cache_key = f"rec:trending:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached[:limit]

        try:
            data = await self._lastfm._api_get("chart.gettopartists", {"limit": limit})
            if not data:
                return []

            items = data.get("artists", {}).get("artist", [])
            if isinstance(items, dict):
                items = [items]

            trending = []
            for item in items:
                images = item.get("image", [])
                image_url = next((i.get("#text") for i in reversed(images) if i.get("#text")), None)
                if not _is_real_image(image_url):
                    image_url = None
                trending.append({
                    "name": item.get("name", ""),
                    "image_url": image_url,
                    "platform": "lastfm",
                    "platform_id": item.get("mbid") or normalize_name(item.get("name", "")),
                    "url": item.get("url", ""),
                    "match_score": 0.0,
                    "listeners": int(item.get("listeners", 0)),
                })

            # Enrich with Spotify images for artists missing images
            await self._enrich_images(trending)

            await cache_set(cache_key, trending, DISCOVER_CACHE_TTL)
            return trending
        except Exception:
            return []

    async def _enrich_images(self, artists: list[dict]) -> None:
        """Fetch images from Spotify or YouTube for artists that have no image."""
        needs_image = [a for a in artists if not a.get("image_url")]
        if not needs_image:
            return

        async def _fetch_image(artist: dict) -> None:
            name = artist.get("name", "")
            # Check per-artist image cache first
            img_cache_key = f"rec:img:{normalize_name(name)}"
            cached_img = await cache_get(img_cache_key)
            if cached_img:
                artist["image_url"] = cached_img
                return

            # Try Spotify first
            try:
                results = await self._spotify.search_artists(name, limit=1)
                if results and _is_real_image(results[0].image_url):
                    artist["image_url"] = results[0].image_url
                    await cache_set(img_cache_key, artist["image_url"], 86400)
                    return
            except Exception:
                pass
            # Fallback to YouTube channel thumbnail
            if self._youtube:
                try:
                    results = await self._youtube.search_artists(name, limit=1)
                    if results and results[0].image_url:
                        artist["image_url"] = results[0].image_url
                        await cache_set(img_cache_key, artist["image_url"], 86400)
                        return
                except Exception:
                    pass

        await asyncio.gather(*[_fetch_image(a) for a in needs_image])

    async def _lastfm_similar_by_name(self, artist_name: str, limit: int) -> list[SourceArtist]:
        """Search Last.fm for artist, then get similar."""
        artists = await self._lastfm.search_artists(artist_name, limit=1)
        if not artists:
            return []
        pid = artists[0].platform_id
        return await self._lastfm.get_similar_artists(pid, limit=limit)

    async def _spotify_related(self, spotify_id: str) -> list[SourceArtist]:
        """Get Spotify related artists."""
        data = await self._spotify._api_get(f"artists/{spotify_id}/related-artists")
        if not data:
            return []

        artists = []
        for item in data.get("artists", []):
            images = item.get("images", [])
            artists.append(SourceArtist(
                platform="spotify",
                platform_id=item.get("id", ""),
                name=item.get("name", ""),
                url=item.get("external_urls", {}).get("spotify"),
                image_url=images[0]["url"] if images else None,
                follower_count=item.get("followers", {}).get("total"),
                extra={"match": 0.5},  # Default relevance
            ))
        return artists

    async def _spotify_related_by_name(self, artist_name: str) -> list[SourceArtist]:
        """Search Spotify for artist, then get related."""
        artists = await self._spotify.search_artists(artist_name, limit=1)
        if not artists:
            return []
        return await self._spotify_related(artists[0].platform_id)
