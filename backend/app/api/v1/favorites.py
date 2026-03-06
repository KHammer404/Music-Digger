"""Favorites API."""

import uuid

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import Favorite

router = APIRouter()


class FavoriteRequest(BaseModel):
    user_id: str
    target_type: str  # "track" or "artist"
    target_id: str


class FavoriteResponse(BaseModel):
    id: str
    target_type: str
    target_id: str
    created_at: str


@router.post("")
async def add_favorite(req: FavoriteRequest, db: AsyncSession = Depends(get_db)):
    # Check if already favorited
    result = await db.execute(
        select(Favorite).where(and_(
            Favorite.user_id == uuid.UUID(req.user_id),
            Favorite.target_type == req.target_type,
            Favorite.target_id == uuid.UUID(req.target_id),
        ))
    )
    existing = result.scalar_one_or_none()
    if existing:
        return {"status": "already_exists", "id": str(existing.id)}

    fav = Favorite(
        user_id=uuid.UUID(req.user_id),
        target_type=req.target_type,
        target_id=uuid.UUID(req.target_id),
    )
    db.add(fav)
    await db.flush()
    return {"status": "added", "id": str(fav.id)}


@router.delete("/{favorite_id}")
async def remove_favorite(favorite_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Favorite).where(Favorite.id == uuid.UUID(favorite_id)))
    fav = result.scalar_one_or_none()
    if fav:
        await db.delete(fav)
    return {"status": "removed"}


@router.get("", response_model=list[FavoriteResponse])
async def list_favorites(
    user_id: str = Query(...),
    target_type: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    try:
        uid = uuid.UUID(user_id)
    except ValueError:
        return []
    query = select(Favorite).where(Favorite.user_id == uid)
    if target_type:
        query = query.where(Favorite.target_type == target_type)
    query = query.order_by(Favorite.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    favorites = result.scalars().all()

    return [
        FavoriteResponse(
            id=str(f.id),
            target_type=f.target_type,
            target_id=str(f.target_id),
            created_at=f.created_at.isoformat() if f.created_at else "",
        )
        for f in favorites
    ]
