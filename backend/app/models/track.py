import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Float, ForeignKey, Index, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Track(Base):
    __tablename__ = "tracks"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    normalized_title: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    isrc: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    album_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("albums.id"), nullable=True)
    dedup_group_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("dedup_groups.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    album: Mapped["Album | None"] = relationship(back_populates="tracks")
    track_artists: Mapped[list["TrackArtist"]] = relationship(back_populates="track", cascade="all, delete-orphan")
    sources: Mapped[list["TrackSource"]] = relationship(back_populates="track", cascade="all, delete-orphan")
    dedup_group: Mapped["DedupGroup | None"] = relationship(back_populates="tracks")

    __table_args__ = (
        Index("ix_tracks_title_trgm", "title", postgresql_using="gin",
              postgresql_ops={"title": "gin_trgm_ops"}),
    )


class TrackArtist(Base):
    __tablename__ = "track_artists"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    track_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tracks.id", ondelete="CASCADE"), nullable=False)
    artist_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("artists.id", ondelete="CASCADE"), nullable=False)
    role: Mapped[str] = mapped_column(String(50), default="primary")  # primary, featured, producer, circle

    track: Mapped["Track"] = relationship(back_populates="track_artists")
    artist: Mapped["Artist"] = relationship(back_populates="track_artists")

    __table_args__ = (
        Index("ix_track_artist_unique", "track_id", "artist_id", "role", unique=True),
    )


class TrackSource(Base):
    __tablename__ = "track_sources"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    track_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("tracks.id", ondelete="CASCADE"), nullable=False)
    platform: Mapped[str] = mapped_column(String(50), nullable=False)  # youtube, spotify, niconico, etc.
    platform_track_id: Mapped[str] = mapped_column(String(500), nullable=False)
    url: Mapped[str] = mapped_column(Text, nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    view_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    like_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_playable: Mapped[bool] = mapped_column(default=True)
    quality_score: Mapped[float | None] = mapped_column(Float, nullable=True)  # for priority ranking
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    track: Mapped["Track"] = relationship(back_populates="sources")

    __table_args__ = (
        Index("ix_track_source_unique", "platform", "platform_track_id", unique=True),
    )


class Album(Base):
    __tablename__ = "albums"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    release_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    album_type: Mapped[str | None] = mapped_column(String(50), nullable=True)  # album, single, ep, compilation
    platform: Mapped[str | None] = mapped_column(String(50), nullable=True)
    platform_album_id: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    tracks: Mapped[list["Track"]] = relationship(back_populates="album")


class DedupGroup(Base):
    __tablename__ = "dedup_groups"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    representative_track_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    confidence: Mapped[float] = mapped_column(Float, default=1.0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    tracks: Mapped[list["Track"]] = relationship(back_populates="dedup_group")
