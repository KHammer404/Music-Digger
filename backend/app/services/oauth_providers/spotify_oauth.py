import logging
from urllib.parse import urlencode

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

SPOTIFY_AUTH_URL = "https://accounts.spotify.com/authorize"
SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_API_BASE = "https://api.spotify.com/v1"

SCOPES = "playlist-read-private playlist-read-collaborative"


class SpotifyOAuthProvider:
    def get_authorize_url(self, state: str) -> str:
        params = {
            "client_id": settings.spotify_client_id,
            "response_type": "code",
            "redirect_uri": f"{settings.oauth_redirect_base}/spotify/callback",
            "scope": SCOPES,
            "state": state,
            "show_dialog": "true",
        }
        return f"{SPOTIFY_AUTH_URL}?{urlencode(params)}"

    def generate_state_data(self) -> dict | None:
        return None

    async def exchange_code(self, code: str, state_data: dict) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": f"{settings.oauth_redirect_base}/spotify/callback",
                    "client_id": settings.spotify_client_id,
                    "client_secret": settings.spotify_client_secret,
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
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.spotify_client_id,
                    "client_secret": settings.spotify_client_secret,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                "access_token": data["access_token"],
                "refresh_token": data.get("refresh_token", refresh_token),
                "expires_in": data.get("expires_in", 3600),
            }

    async def get_user_info(self, access_token: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{SPOTIFY_API_BASE}/me",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                "id": data["id"],
                "display_name": data.get("display_name", data["id"]),
            }

    async def get_user_playlists(self, access_token: str) -> list[dict]:
        playlists = []
        url = f"{SPOTIFY_API_BASE}/me/playlists?limit=50"

        async with httpx.AsyncClient() as client:
            while url:
                resp = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                data = resp.json()

                for item in data.get("items", []):
                    playlists.append({
                        "id": item["id"],
                        "name": item["name"],
                        "description": item.get("description", ""),
                        "track_count": item["tracks"]["total"],
                        "image_url": item["images"][0]["url"] if item.get("images") else None,
                        "owner": item["owner"]["display_name"],
                    })

                url = data.get("next")

        return playlists

    async def get_playlist_tracks(self, access_token: str, playlist_id: str) -> list[dict]:
        tracks = []
        url = f"{SPOTIFY_API_BASE}/playlists/{playlist_id}/tracks?limit=100"

        async with httpx.AsyncClient() as client:
            while url:
                resp = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                resp.raise_for_status()
                data = resp.json()

                for item in data.get("items", []):
                    track = item.get("track")
                    if not track or track.get("is_local"):
                        continue
                    artists = [a["name"] for a in track.get("artists", [])]
                    tracks.append({
                        "title": track["name"],
                        "artist": ", ".join(artists),
                        "duration_seconds": track.get("duration_ms", 0) // 1000,
                        "isrc": track.get("external_ids", {}).get("isrc"),
                        "platform": "spotify",
                        "platform_track_id": track["id"],
                        "url": track.get("external_urls", {}).get("spotify", ""),
                        "thumbnail_url": track["album"]["images"][0]["url"] if track.get("album", {}).get("images") else None,
                    })

                url = data.get("next")

        return tracks
