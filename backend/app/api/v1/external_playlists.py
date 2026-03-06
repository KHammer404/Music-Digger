import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.track import Track, TrackSource
from app.models.user import Playlist, PlaylistTrack
from app.services.oauth_service import get_valid_token
from app.services.oauth_providers import get_provider

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/{platform}")
async def list_external_playlists(
    platform: str,
    user_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """List user's playlists from an external platform."""
    try:
        token = await get_valid_token(user_id, platform, db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    provider = get_provider(platform)
    try:
        playlists = await provider.get_user_playlists(token)
    except Exception as e:
        logger.exception("Failed to fetch %s playlists", platform)
        raise HTTPException(status_code=502, detail=f"Failed to fetch playlists from {platform}")

    return {"playlists": playlists}


@router.get("/{platform}/{playlist_id}/tracks")
async def preview_external_tracks(
    platform: str,
    playlist_id: str,
    user_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    """Preview tracks from an external playlist before importing."""
    try:
        token = await get_valid_token(user_id, platform, db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    provider = get_provider(platform)
    try:
        tracks = await provider.get_playlist_tracks(token, playlist_id)
    except Exception as e:
        logger.exception("Failed to fetch %s playlist tracks", platform)
        raise HTTPException(status_code=502, detail=f"Failed to fetch tracks from {platform}")

    return {"tracks": tracks, "total": len(tracks)}


@router.post("/{platform}/{playlist_id}/import")
async def import_external_playlist(
    platform: str,
    playlist_id: str,
    user_id: str = Query(...),
    playlist_name: str = Query(None, description="Override playlist name"),
    db: AsyncSession = Depends(get_db),
):
    """Import an external playlist into the local library."""
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user_id")

    try:
        token = await get_valid_token(user_id, platform, db)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    provider = get_provider(platform)

    # Fetch playlist info and tracks
    try:
        all_playlists = await provider.get_user_playlists(token)
        ext_playlist = next((p for p in all_playlists if p["id"] == playlist_id), None)
        tracks_data = await provider.get_playlist_tracks(token, playlist_id)
    except Exception as e:
        logger.exception("Failed to fetch data for import from %s", platform)
        raise HTTPException(status_code=502, detail=f"Failed to fetch data from {platform}")

    name = playlist_name or (ext_playlist["name"] if ext_playlist else f"{platform.capitalize()} Import")

    # Create local playlist
    local_playlist = Playlist(
        user_id=uid,
        name=name,
        description=f"Imported from {platform.capitalize()}",
        image_url=ext_playlist.get("image_url") if ext_playlist else None,
    )
    db.add(local_playlist)
    await db.flush()

    # Process each track
    imported_count = 0
    for position, track_data in enumerate(tracks_data):
        # Try to find existing track by ISRC
        local_track = None
        if track_data.get("isrc"):
            result = await db.execute(
                select(Track).where(Track.isrc == track_data["isrc"])
            )
            local_track = result.scalar_one_or_none()

        # Try to find by platform track ID
        if not local_track and track_data.get("platform_track_id"):
            result = await db.execute(
                select(TrackSource).where(
                    TrackSource.platform == track_data["platform"],
                    TrackSource.platform_track_id == track_data["platform_track_id"],
                )
            )
            existing_source = result.scalar_one_or_none()
            if existing_source:
                local_track = await db.get(Track, existing_source.track_id)

        # Create new track if not found
        if not local_track:
            from unidecode import unidecode
            local_track = Track(
                title=track_data["title"],
                normalized_title=unidecode(track_data["title"]).lower(),
                duration_seconds=track_data.get("duration_seconds"),
                isrc=track_data.get("isrc"),
            )
            db.add(local_track)
            await db.flush()

            # Create track source
            if track_data.get("platform_track_id"):
                source = TrackSource(
                    track_id=local_track.id,
                    platform=track_data["platform"],
                    platform_track_id=track_data["platform_track_id"],
                    url=track_data.get("url", ""),
                    thumbnail_url=track_data.get("thumbnail_url"),
                    is_playable=True,
                )
                db.add(source)

        # Add to playlist
        playlist_track = PlaylistTrack(
            playlist_id=local_playlist.id,
            track_id=local_track.id,
            position=position,
        )
        db.add(playlist_track)
        imported_count += 1

    await db.flush()

    return {
        "playlist_id": str(local_playlist.id),
        "playlist_name": name,
        "imported_tracks": imported_count,
        "total_tracks": len(tracks_data),
    }
