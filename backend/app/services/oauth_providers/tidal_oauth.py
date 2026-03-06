import hashlib
import base64
import logging
import secrets
from urllib.parse import urlencode

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

TIDAL_AUTH_URL = "https://login.tidal.com/authorize"
TIDAL_TOKEN_URL = "https://auth.tidal.com/v1/oauth2/token"
TIDAL_API_BASE = "https://openapi.tidal.com/v2"

SCOPES = "playlists.read"


class TidalOAuthProvider:
    def get_authorize_url(self, state: str) -> str:
        # PKCE: code_verifier is stored in state_data via generate_state_data()
        # We need to get it from the state, but since this is called before storage,
        # we'll generate it here and the caller stores it
        # The state_data already contains code_verifier from generate_state_data()
        # We'll use state as seed to reconstruct — actually, we store it in cache via oauth_service
        # Since we can't access state_data here, we use a deterministic approach:
        # generate_state_data is called BEFORE this, and stored. But we need the verifier HERE.
        # Solution: store verifier on instance temporarily
        code_verifier = getattr(self, '_pending_code_verifier', secrets.token_urlsafe(64))
        code_challenge = base64.urlsafe_b64encode(
            hashlib.sha256(code_verifier.encode()).digest()
        ).rstrip(b"=").decode()

        params = {
            "client_id": settings.tidal_client_id,
            "response_type": "code",
            "redirect_uri": f"{settings.oauth_redirect_base}/tidal/callback",
            "scope": SCOPES,
            "state": state,
            "code_challenge": code_challenge,
            "code_challenge_method": "S256",
        }
        return f"{TIDAL_AUTH_URL}?{urlencode(params)}"

    def generate_state_data(self) -> dict | None:
        code_verifier = secrets.token_urlsafe(64)
        self._pending_code_verifier = code_verifier
        return {"code_verifier": code_verifier}

    async def exchange_code(self, code: str, state_data: dict) -> dict:
        code_verifier = state_data.get("code_verifier", "")

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                TIDAL_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": f"{settings.oauth_redirect_base}/tidal/callback",
                    "client_id": settings.tidal_client_id,
                    "code_verifier": code_verifier,
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
                TIDAL_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                    "client_id": settings.tidal_client_id,
                    "client_secret": settings.tidal_client_secret,
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
                f"{TIDAL_API_BASE}/userInfo",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.tidal.v1+json",
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return {
                "id": str(data.get("userId", data.get("sub", "unknown"))),
                "display_name": data.get("username", data.get("name", "Tidal User")),
            }

    async def get_user_playlists(self, access_token: str) -> list[dict]:
        playlists = []

        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{TIDAL_API_BASE}/my/playlists",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.tidal.v1+json",
                },
                params={"limit": 100},
            )
            resp.raise_for_status()
            data = resp.json()

            for item in data.get("data", []):
                attrs = item.get("attributes", item)
                playlists.append({
                    "id": item.get("id", attrs.get("uuid", "")),
                    "name": attrs.get("name", attrs.get("title", "Untitled")),
                    "description": attrs.get("description", ""),
                    "track_count": attrs.get("numberOfTracks", 0),
                    "image_url": None,
                    "owner": attrs.get("creator", {}).get("name", "You"),
                })

        return playlists

    async def get_playlist_tracks(self, access_token: str, playlist_id: str) -> list[dict]:
        tracks = []

        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{TIDAL_API_BASE}/playlists/{playlist_id}/relationships/items",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Accept": "application/vnd.tidal.v1+json",
                },
                params={"limit": 100},
            )
            resp.raise_for_status()
            data = resp.json()

            for item in data.get("data", []):
                attrs = item.get("attributes", item)
                track_id = item.get("id", "")
                artists_list = attrs.get("artists", [])
                artist_name = ", ".join(a.get("name", "") for a in artists_list) if artists_list else attrs.get("artistName", "Unknown")

                tracks.append({
                    "title": attrs.get("title", "Unknown"),
                    "artist": artist_name,
                    "duration_seconds": attrs.get("duration"),
                    "isrc": attrs.get("isrc"),
                    "platform": "tidal",
                    "platform_track_id": str(track_id),
                    "url": f"https://tidal.com/track/{track_id}",
                    "thumbnail_url": None,
                })

        return tracks
