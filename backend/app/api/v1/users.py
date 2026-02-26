"""User registration and management API."""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User

router = APIRouter()


class RegisterRequest(BaseModel):
    device_id: str
    nickname: str | None = None


class UserResponse(BaseModel):
    id: str
    device_id: str
    nickname: str | None


@router.post("/register", response_model=UserResponse)
async def register_user(req: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register or retrieve an anonymous user by device ID."""
    result = await db.execute(select(User).where(User.device_id == req.device_id))
    user = result.scalar_one_or_none()

    if user:
        return UserResponse(id=str(user.id), device_id=user.device_id, nickname=user.nickname)

    user = User(device_id=req.device_id, nickname=req.nickname)
    db.add(user)
    await db.flush()

    return UserResponse(id=str(user.id), device_id=user.device_id, nickname=user.nickname)


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(id=str(user.id), device_id=user.device_id, nickname=user.nickname)
