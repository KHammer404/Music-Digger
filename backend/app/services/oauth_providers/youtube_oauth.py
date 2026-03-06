import logging
from urllib.parse import urlencode

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"
YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"

SCOPES = "https://www.googleapis.com/auth/youtube.readonly"


class YouTubeOAuthProvider:
    def get_authorize_url(self, state: str) -> str:
        params = {
            "client_id": settings.youtube_client_id,
            "response_type": "code",
            "redirect_uri": f"{settings.oauth_redirect_base}/youtube/callback",
            "scope": SCOPES,
            "state": state,
            "access_type": "offline",
            "prompt": "consent",
        }
        return f"{GOOGLE_AUTH_URL}?{urlencode(params)}"

    def generate_state_data(self) -> dict | None:
        return None

    async def exchange_code(self, code: str, state_data: dict) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": f"{settings.oauth_redirect_base}/youtube/callback",
                    "client_id": settings.youtube_client_id,
                    "client_secret": settings.youtube_client_secret,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                "access_token": data["access_token"],
                "refresh_token": data.get("refresh_token"),
                "expires_in": data.get("expires_in", 3600),
            }

    async def refresh_access_token(self, refresh_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                GOOGLE_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.youtube_client_id,
                    "client_secret": settings.youtube_client_secret,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                "access_token": data["access_token"],
                "refresh_token": refresh_token,  # Google doesn't always return new refresh token
                "expires_in": data.get("expires_in", 3600),
            }

    async def get_user_info(self, access_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{YOUTUBE_API_BASE}/channels",
                params={"part": "snippet", "mine": "true"},
                headers={"Authorization": f"Bearer {access_token}"},
            )
            resp.raise_for_status()
            data = resp.json()
            items = data.get("items", [])
            if not items:
                return {"id": "unknown", "display_name": "YouTube User"}
            channel = items[0]
            return {
                "id": channel["id"],
                "display_name": channel["snippet"]["title"],
            }

    async def get_user_playlists(self, access_token: str) -> list[dict]:
        playlists = []
        page_token = None

        async with httpx.AsyncClient() as client:
            while True:
                params = {"part": "snippet,contentDetails", "mine": "true", "maxResults": 50}
                if page_token:
                    params["pageToken"] = page_token

                resp = await client.get(
                    f"{YOUTUBE_API_BASE}/playlists",
                    params=params,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                data = resp.json()

                for item in data.get("items", []):
                    thumbnails = item["snippet"].get("thumbnails", {})
                    thumb = thumbnails.get("medium", thumbnails.get("default", {}))
                    playlists.append({
                        "id": item["id"],
                        "name": item["snippet"]["title"],
                        "description": item["snippet"].get("description", ""),
                        "track_count": item["contentDetails"]["itemCount"],
                        "image_url": thumb.get("url"),
                        "owner": item["snippet"]["channelTitle"],
                    })

                page_token = data.get("nextPageToken")
                if not page_token:
                    break

        return playlists

    async def get_playlist_tracks(self, access_token: str, playlist_id: str) -> list[dict]:
        tracks = []
        page_token = None

        async with httpx.AsyncClient() as client:
            while True:
                params = {"part": "snippet,contentDetails", "playlistId": playlist_id, "maxResults": 50}
                if page_token:
                    params["pageToken"] = page_token

                resp = await client.get(
                    f"{YOUTUBE_API_BASE}/playlistItems",
                    params=params,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                data = resp.json()

                for item in data.get("items", []):
                    snippet = item["snippet"]
                    video_id = snippet.get("resourceId", {}).get("videoId")
                    if not video_id:
                        continue
                    thumbnails = snippet.get("thumbnails", {})
                    thumb = thumbnails.get("medium", thumbnails.get("default", {}))
                    tracks.append({
                        "title": snippet["title"],
                        "artist": snippet.get("videoOwnerChannelTitle", "Unknown"),
                        "duration_seconds": None,
                        "isrc": None,
                        "platform": "youtube",
                        "platform_track_id": video_id,
                        "url": f"https://www.youtube.com/watch?v={video_id}",
                        "thumbnail_url": thumb.get("url"),
                    })

                page_token = data.get("nextPageToken")
                if not page_token:
                    break

        return tracks
