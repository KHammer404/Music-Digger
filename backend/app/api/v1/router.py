from fastapi import APIRouter

from app.api.v1 import artists, export_import, favorites, health, history, playlists, playback, recommendations, search, users

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(health.router, tags=["health"])
api_router.include_router(search.router, prefix="/search", tags=["search"])
api_router.include_router(artists.router, prefix="/artists", tags=["artists"])
api_router.include_router(playback.router, prefix="/playback", tags=["playback"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(playlists.router, prefix="/playlists", tags=["playlists"])
api_router.include_router(favorites.router, prefix="/favorites", tags=["favorites"])
api_router.include_router(history.router, prefix="/history", tags=["history"])
api_router.include_router(recommendations.router, prefix="/recommendations", tags=["recommendations"])
api_router.include_router(export_import.router, prefix="/export", tags=["export/import"])
