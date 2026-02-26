"""Digging history API — automatically records search, views, and plays."""

import uuid

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import DiggingHistory

router = APIRouter()


class HistoryRecordRequest(BaseModel):
    user_id: str
    action: str  # search, view_artist, play_track
    target_type: str | None = None
    target_id: str | None = None
    query: str | None = None
    platform: str | None = None


class HistoryResponse(BaseModel):
    id: str
    action: str
    target_type: str | None
    target_id: str | None
    query: str | None
    platform: str | None
    created_at: str


@router.post("")
async def record_history(req: HistoryRecordRequest, db: AsyncSession = Depends(get_db)):
    record = DiggingHistory(
        user_id=uuid.UUID(req.user_id),
        action=req.action,
        target_type=req.target_type,
        target_id=uuid.UUID(req.target_id) if req.target_id else None,
        query=req.query,
        platform=req.platform,
    )
    db.add(record)
    await db.flush()
    return {"status": "recorded", "id": str(record.id)}


@router.get("", response_model=list[HistoryResponse])
async def list_history(
    user_id: str = Query(...),
    action: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    query = select(DiggingHistory).where(DiggingHistory.user_id == uuid.UUID(user_id))
    if action:
        query = query.where(DiggingHistory.action == action)
    query = query.order_by(DiggingHistory.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    records = result.scalars().all()

    return [
        HistoryResponse(
            id=str(r.id),
            action=r.action,
            target_type=r.target_type,
            target_id=str(r.target_id) if r.target_id else None,
            query=r.query,
            platform=r.platform,
            created_at=r.created_at.isoformat() if r.created_at else "",
        )
        for r in records
    ]
