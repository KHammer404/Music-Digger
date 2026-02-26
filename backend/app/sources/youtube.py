"""YouTube source adapter using YouTube Data API v3."""

import re
from datetime import timedelta

import httpx

from app.cache.redis_cache import cache_get, cache_set
from app.config import get_settings
from app.matching.name_normalizer import extract_title_and_artist, normalize_name
from app.sources.base import SourceAdapter, SourceArtist, SourceTrack

settings = get_settings()

# Cache TTLs
SEARCH_CACHE_TTL = 3600       # 1 hour
ARTIST_CACHE_TTL = 86400      # 24 hours
TRACKS_CACHE_TTL = 43200      # 12 hours

YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"


def _parse_iso8601_duration(duration: str) -> int | None:
    """Parse ISO 8601 duration (e.g., PT4M33S) to seconds."""
    if not duration:
        return None
    match = re.match(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', duration)
    if not match:
        return None
    hours = int(match.group(1) or 0)
    minutes = int(match.group(2) or 0)
    seconds = int(match.group(3) or 0)
    return int(timedelta(hours=hours, minutes=minutes, seconds=seconds).total_seconds())


class YouTubeAdapter(SourceAdapter):
    """YouTube Data API v3 adapter."""

    def __init__(self):
        self._api_key = settings.youtube_api_key
        self._client = httpx.AsyncClient(timeout=15.0)

    @property
    def platform_name(self) -> str:
        return "youtube"

    @property
    def display_name(self) -> str:
        return "YouTube"

    async def _api_request(self, endpoint: str, params: dict) -> dict | None:
        """Make a YouTube API request."""
        params["key"] = self._api_key
        try:
            response = await self._client.get(
                f"{YOUTUBE_API_BASE}/{endpoint}",
                params=params,
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError:
            return None

    async def search_artists(self, query: str, limit: int = 10) -> list[SourceArtist]:
        cache_key = f"yt:search_artists:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceArtist(**a) for a in cached]

        data = await self._api_request("search", {
            "part": "snippet",
            "q": query,
            "type": "channel",
            "maxResults": min(limit, 50),
        })
        if not data:
            return []

        artists = []
        for item in data.get("items", []):
            snippet = item.get("snippet", {})
            channel_id = item.get("id", {}).get("channelId", "")
            artists.append(SourceArtist(
                platform="youtube",
                platform_id=channel_id,
                name=snippet.get("title", ""),
                url=f"https://www.youtube.com/channel/{channel_id}",
                image_url=snippet.get("thumbnails", {}).get("high", {}).get("url"),
                description=snippet.get("description", ""),
            ))

        await cache_set(cache_key, [a.__dict__ for a in artists], SEARCH_CACHE_TTL)
        return artists

    async def search_tracks(self, query: str, limit: int = 20) -> list[SourceTrack]:
        cache_key = f"yt:search_tracks:{normalize_name(query)}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        data = await self._api_request("search", {
            "part": "snippet",
            "q": query,
            "type": "video",
            "videoCategoryId": "10",  # Music category
            "maxResults": min(limit, 50),
        })
        if not data:
            return []

        # Get video IDs for duration info
        video_ids = [
            item.get("id", {}).get("videoId", "")
            for item in data.get("items", [])
            if item.get("id", {}).get("videoId")
        ]

        durations = await self._get_video_durations(video_ids)
        stats = await self._get_video_stats(video_ids)

        tracks = []
        for item in data.get("items", []):
            snippet = item.get("snippet", {})
            video_id = item.get("id", {}).get("videoId", "")
            if not video_id:
                continue

            video_title = snippet.get("title", "")
            title, artist_name = extract_title_and_artist(video_title)
            if not artist_name:
                artist_name = snippet.get("channelTitle", "")

            video_stats = stats.get(video_id, {})

            tracks.append(SourceTrack(
                platform="youtube",
                platform_id=video_id,
                title=title or video_title,
                artist_name=artist_name,
                url=f"https://www.youtube.com/watch?v={video_id}",
                duration_seconds=durations.get(video_id),
                thumbnail_url=snippet.get("thumbnails", {}).get("high", {}).get("url"),
                view_count=int(video_stats.get("viewCount", 0)) if video_stats.get("viewCount") else None,
                like_count=int(video_stats.get("likeCount", 0)) if video_stats.get("likeCount") else None,
                release_date=snippet.get("publishedAt", "")[:10] if snippet.get("publishedAt") else None,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], SEARCH_CACHE_TTL)
        return tracks

    async def get_artist(self, platform_id: str) -> SourceArtist | None:
        cache_key = f"yt:artist:{platform_id}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return SourceArtist(**cached)

        data = await self._api_request("channels", {
            "part": "snippet,statistics",
            "id": platform_id,
        })
        if not data or not data.get("items"):
            return None

        item = data["items"][0]
        snippet = item.get("snippet", {})
        stats = item.get("statistics", {})

        artist = SourceArtist(
            platform="youtube",
            platform_id=platform_id,
            name=snippet.get("title", ""),
            url=f"https://www.youtube.com/channel/{platform_id}",
            image_url=snippet.get("thumbnails", {}).get("high", {}).get("url"),
            description=snippet.get("description", ""),
            follower_count=int(stats.get("subscriberCount", 0)) if stats.get("subscriberCount") else None,
            extra={"video_count": int(stats.get("videoCount", 0)) if stats.get("videoCount") else 0},
        )

        await cache_set(cache_key, artist.__dict__, ARTIST_CACHE_TTL)
        return artist

    async def get_artist_tracks(self, platform_id: str, limit: int = 50) -> list[SourceTrack]:
        cache_key = f"yt:artist_tracks:{platform_id}:{limit}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return [SourceTrack(**t) for t in cached]

        # First, get the uploads playlist ID
        channel_data = await self._api_request("channels", {
            "part": "contentDetails",
            "id": platform_id,
        })
        if not channel_data or not channel_data.get("items"):
            return []

        uploads_playlist_id = (
            channel_data["items"][0]
            .get("contentDetails", {})
            .get("relatedPlaylists", {})
            .get("uploads")
        )
        if not uploads_playlist_id:
            return []

        # Get videos from uploads playlist
        all_video_ids = []
        next_page_token = None
        fetched = 0

        while fetched < limit:
            params = {
                "part": "snippet",
                "playlistId": uploads_playlist_id,
                "maxResults": min(50, limit - fetched),
            }
            if next_page_token:
                params["pageToken"] = next_page_token

            playlist_data = await self._api_request("playlistItems", params)
            if not playlist_data:
                break

            for item in playlist_data.get("items", []):
                video_id = item.get("snippet", {}).get("resourceId", {}).get("videoId")
                if video_id:
                    all_video_ids.append((video_id, item.get("snippet", {})))
                    fetched += 1

            next_page_token = playlist_data.get("nextPageToken")
            if not next_page_token:
                break

        if not all_video_ids:
            return []

        # Get durations and stats for all videos
        video_ids = [vid for vid, _ in all_video_ids]
        durations = await self._get_video_durations(video_ids)
        stats = await self._get_video_stats(video_ids)

        # Get channel name
        artist = await self.get_artist(platform_id)
        channel_name = artist.name if artist else ""

        tracks = []
        for video_id, snippet in all_video_ids:
            video_title = snippet.get("title", "")
            title, artist_name = extract_title_and_artist(video_title)
            if not artist_name:
                artist_name = channel_name

            video_stats = stats.get(video_id, {})

            tracks.append(SourceTrack(
                platform="youtube",
                platform_id=video_id,
                title=title or video_title,
                artist_name=artist_name,
                url=f"https://www.youtube.com/watch?v={video_id}",
                duration_seconds=durations.get(video_id),
                thumbnail_url=snippet.get("thumbnails", {}).get("high", {}).get("url"),
                view_count=int(video_stats.get("viewCount", 0)) if video_stats.get("viewCount") else None,
                like_count=int(video_stats.get("likeCount", 0)) if video_stats.get("likeCount") else None,
                release_date=snippet.get("publishedAt", "")[:10] if snippet.get("publishedAt") else None,
            ))

        await cache_set(cache_key, [t.__dict__ for t in tracks], TRACKS_CACHE_TTL)
        return tracks

    async def _get_video_durations(self, video_ids: list[str]) -> dict[str, int | None]:
        """Get durations for a batch of video IDs."""
        if not video_ids:
            return {}

        result = {}
        # YouTube API accepts max 50 IDs per request
        for i in range(0, len(video_ids), 50):
            batch = video_ids[i:i + 50]
            data = await self._api_request("videos", {
                "part": "contentDetails",
                "id": ",".join(batch),
            })
            if data:
                for item in data.get("items", []):
                    vid = item.get("id", "")
                    duration_str = item.get("contentDetails", {}).get("duration", "")
                    result[vid] = _parse_iso8601_duration(duration_str)

        return result

    async def _get_video_stats(self, video_ids: list[str]) -> dict[str, dict]:
        """Get statistics for a batch of video IDs."""
        if not video_ids:
            return {}

        result = {}
        for i in range(0, len(video_ids), 50):
            batch = video_ids[i:i + 50]
            data = await self._api_request("videos", {
                "part": "statistics",
                "id": ",".join(batch),
            })
            if data:
                for item in data.get("items", []):
                    result[item.get("id", "")] = item.get("statistics", {})

        return result

    async def is_available(self) -> bool:
        return bool(self._api_key)
