"""Playlist CRUD API."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import Playlist, PlaylistTrack

router = APIRouter()


class PlaylistCreateRequest(BaseModel):
    user_id: str
    name: str
    description: str | None = None


class PlaylistResponse(BaseModel):
    id: str
    name: str
    description: str | None
    track_count: int
    image_url: str | None


class AddTrackRequest(BaseModel):
    track_id: str


@router.post("", response_model=PlaylistResponse)
async def create_playlist(req: PlaylistCreateRequest, db: AsyncSession = Depends(get_db)):
    playlist = Playlist(
        user_id=uuid.UUID(req.user_id),
        name=req.name,
        description=req.description,
    )
    db.add(playlist)
    await db.flush()

    return PlaylistResponse(
        id=str(playlist.id), name=playlist.name,
        description=playlist.description, track_count=0, image_url=None,
    )


@router.get("", response_model=list[PlaylistResponse])
async def list_playlists(
    user_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Playlist).where(Playlist.user_id == uuid.UUID(user_id)).order_by(Playlist.updated_at.desc())
    )
    playlists = result.scalars().all()

    responses = []
    for pl in playlists:
        count_result = await db.execute(
            select(func.count()).select_from(PlaylistTrack).where(PlaylistTrack.playlist_id == pl.id)
        )
        count = count_result.scalar() or 0
        responses.append(PlaylistResponse(
            id=str(pl.id), name=pl.name,
            description=pl.description, track_count=count, image_url=pl.image_url,
        ))
    return responses


@router.get("/{playlist_id}", response_model=PlaylistResponse)
async def get_playlist(playlist_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Playlist).where(Playlist.id == uuid.UUID(playlist_id)))
    pl = result.scalar_one_or_none()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    count_result = await db.execute(
        select(func.count()).select_from(PlaylistTrack).where(PlaylistTrack.playlist_id == pl.id)
    )
    count = count_result.scalar() or 0

    return PlaylistResponse(
        id=str(pl.id), name=pl.name,
        description=pl.description, track_count=count, image_url=pl.image_url,
    )


@router.delete("/{playlist_id}")
async def delete_playlist(playlist_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Playlist).where(Playlist.id == uuid.UUID(playlist_id)))
    pl = result.scalar_one_or_none()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")
    await db.delete(pl)
    return {"status": "deleted"}


@router.post("/{playlist_id}/tracks")
async def add_track_to_playlist(
    playlist_id: str,
    req: AddTrackRequest,
    db: AsyncSession = Depends(get_db),
):
    # Get max position
    result = await db.execute(
        select(func.max(PlaylistTrack.position)).where(PlaylistTrack.playlist_id == uuid.UUID(playlist_id))
    )
    max_pos = result.scalar() or 0

    pt = PlaylistTrack(
        playlist_id=uuid.UUID(playlist_id),
        track_id=uuid.UUID(req.track_id),
        position=max_pos + 1,
    )
    db.add(pt)
    return {"status": "added", "position": max_pos + 1}


@router.delete("/{playlist_id}/tracks/{track_id}")
async def remove_track_from_playlist(
    playlist_id: str,
    track_id: str,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(PlaylistTrack).where(
            PlaylistTrack.playlist_id == uuid.UUID(playlist_id),
            PlaylistTrack.track_id == uuid.UUID(track_id),
        )
    )
    pt = result.scalar_one_or_none()
    if pt:
        await db.delete(pt)
    return {"status": "removed"}
