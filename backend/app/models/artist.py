import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.session import Base


class Artist(Base):
    __tablename__ = "artists"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    canonical_name: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    normalized_name: Mapped[str] = mapped_column(String(500), nullable=False, index=True)
    image_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    aliases: Mapped[list["ArtistAlias"]] = relationship(back_populates="artist", cascade="all, delete-orphan")
    platform_ids: Mapped[list["ArtistPlatformId"]] = relationship(back_populates="artist", cascade="all, delete-orphan")
    track_artists: Mapped[list["TrackArtist"]] = relationship(back_populates="artist")

    __table_args__ = (
        Index("ix_artists_canonical_name_trgm", "canonical_name", postgresql_using="gin",
              postgresql_ops={"canonical_name": "gin_trgm_ops"}),
        Index("ix_artists_normalized_name_trgm", "normalized_name", postgresql_using="gin",
              postgresql_ops={"normalized_name": "gin_trgm_ops"}),
    )


class ArtistAlias(Base):
    __tablename__ = "artist_aliases"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    artist_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("artists.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(500), nullable=False)
    language: Mapped[str | None] = mapped_column(String(10), nullable=True)  # ja, ko, en, etc.
    is_primary: Mapped[bool] = mapped_column(default=False)
    source: Mapped[str | None] = mapped_column(String(50), nullable=True)  # vocadb, musicbrainz, manual
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    artist: Mapped["Artist"] = relationship(back_populates="aliases")

    __table_args__ = (
        Index("ix_artist_aliases_name_trgm", "name", postgresql_using="gin",
              postgresql_ops={"name": "gin_trgm_ops"}),
    )


class ArtistPlatformId(Base):
    __tablename__ = "artist_platform_ids"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    artist_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("artists.id", ondelete="CASCADE"), nullable=False)
    platform: Mapped[str] = mapped_column(String(50), nullable=False)  # spotify, youtube, niconico, etc.
    platform_id: Mapped[str] = mapped_column(String(500), nullable=False)
    platform_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    artist: Mapped["Artist"] = relationship(back_populates="platform_ids")

    __table_args__ = (
        Index("ix_artist_platform_unique", "platform", "platform_id", unique=True),
    )
