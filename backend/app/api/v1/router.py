from fastapi import APIRouter

from app.api.v1 import (
    artists, auth, crosslink, export_import, external_playlists,
    favorites, health, history, playlists, playback, radio,
    recommendations, search, unified_artist, users,
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(health.router, tags=["health"])
api_router.include_router(search.router, prefix="/search", tags=["search"])
api_router.include_router(artists.router, prefix="/artists", tags=["artists"])
api_router.include_router(unified_artist.router, prefix="/artists", tags=["unified-artist"])
api_router.include_router(playback.router, prefix="/playback", tags=["playback"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(playlists.router, prefix="/playlists", tags=["playlists"])
api_router.include_router(favorites.router, prefix="/favorites", tags=["favorites"])
api_router.include_router(history.router, prefix="/history", tags=["history"])
api_router.include_router(recommendations.router, prefix="/recommendations", tags=["recommendations"])
api_router.include_router(export_import.router, prefix="/export", tags=["export/import"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(external_playlists.router, prefix="/external-playlists", tags=["external-playlists"])
api_router.include_router(crosslink.router, prefix="/crosslink", tags=["crosslink"])
api_router.include_router(radio.router, prefix="/radio", tags=["radio"])
