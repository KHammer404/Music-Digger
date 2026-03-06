from app.services.oauth_providers.spotify_oauth import SpotifyOAuthProvider
from app.services.oauth_providers.youtube_oauth import YouTubeOAuthProvider
from app.services.oauth_providers.tidal_oauth import TidalOAuthProvider

_providers = {
    "spotify": SpotifyOAuthProvider(),
    "youtube": YouTubeOAuthProvider(),
    "tidal": TidalOAuthProvider(),
}


def get_provider(platform: str):
    provider = _providers.get(platform)
    if not provider:
        raise ValueError(f"No OAuth provider for platform: {platform}")
    return provider
