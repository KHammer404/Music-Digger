"""Initial schema - all core tables

Revision ID: 001
Revises: None
Create Date: 2026-02-25

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Enable pg_trgm extension for fuzzy search
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # --- artists ---
    op.create_table(
        "artists",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("canonical_name", sa.String(500), nullable=False),
        sa.Column("normalized_name", sa.String(500), nullable=False),
        sa.Column("image_url", sa.Text, nullable=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_artists_canonical_name", "artists", ["canonical_name"])
    op.create_index("ix_artists_normalized_name", "artists", ["normalized_name"])
    op.create_index(
        "ix_artists_canonical_name_trgm", "artists", ["canonical_name"],
        postgresql_using="gin", postgresql_ops={"canonical_name": "gin_trgm_ops"},
    )
    op.create_index(
        "ix_artists_normalized_name_trgm", "artists", ["normalized_name"],
        postgresql_using="gin", postgresql_ops={"normalized_name": "gin_trgm_ops"},
    )

    # --- artist_aliases ---
    op.create_table(
        "artist_aliases",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("artist_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("artists.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(500), nullable=False),
        sa.Column("language", sa.String(10), nullable=True),
        sa.Column("is_primary", sa.Boolean, default=False),
        sa.Column("source", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_artist_aliases_name_trgm", "artist_aliases", ["name"],
        postgresql_using="gin", postgresql_ops={"name": "gin_trgm_ops"},
    )

    # --- artist_platform_ids ---
    op.create_table(
        "artist_platform_ids",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("artist_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("artists.id", ondelete="CASCADE"), nullable=False),
        sa.Column("platform", sa.String(50), nullable=False),
        sa.Column("platform_id", sa.String(500), nullable=False),
        sa.Column("platform_url", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_artist_platform_unique", "artist_platform_ids", ["platform", "platform_id"], unique=True)

    # --- albums ---
    op.create_table(
        "albums",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("release_date", sa.Date, nullable=True),
        sa.Column("image_url", sa.Text, nullable=True),
        sa.Column("album_type", sa.String(50), nullable=True),
        sa.Column("platform", sa.String(50), nullable=True),
        sa.Column("platform_album_id", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_albums_title", "albums", ["title"])

    # --- dedup_groups ---
    op.create_table(
        "dedup_groups",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("representative_track_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("confidence", sa.Float, default=1.0),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- tracks ---
    op.create_table(
        "tracks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("title", sa.String(500), nullable=False),
        sa.Column("normalized_title", sa.String(500), nullable=False),
        sa.Column("duration_seconds", sa.Integer, nullable=True),
        sa.Column("release_date", sa.Date, nullable=True),
        sa.Column("isrc", sa.String(20), nullable=True),
        sa.Column("album_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("albums.id"), nullable=True),
        sa.Column("dedup_group_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dedup_groups.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_tracks_title", "tracks", ["title"])
    op.create_index("ix_tracks_normalized_title", "tracks", ["normalized_title"])
    op.create_index("ix_tracks_isrc", "tracks", ["isrc"])
    op.create_index(
        "ix_tracks_title_trgm", "tracks", ["title"],
        postgresql_using="gin", postgresql_ops={"title": "gin_trgm_ops"},
    )

    # --- track_artists ---
    op.create_table(
        "track_artists",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tracks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("artist_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("artists.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", sa.String(50), default="primary"),
    )
    op.create_index("ix_track_artist_unique", "track_artists", ["track_id", "artist_id", "role"], unique=True)

    # --- track_sources ---
    op.create_table(
        "track_sources",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tracks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("platform", sa.String(50), nullable=False),
        sa.Column("platform_track_id", sa.String(500), nullable=False),
        sa.Column("url", sa.Text, nullable=False),
        sa.Column("thumbnail_url", sa.Text, nullable=True),
        sa.Column("view_count", sa.Integer, nullable=True),
        sa.Column("like_count", sa.Integer, nullable=True),
        sa.Column("is_playable", sa.Boolean, default=True),
        sa.Column("quality_score", sa.Float, nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_track_source_unique", "track_sources", ["platform", "platform_track_id"], unique=True)

    # --- users ---
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("device_id", sa.String(255), unique=True, nullable=False),
        sa.Column("nickname", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("last_active_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_device_id", "users", ["device_id"])

    # --- playlists ---
    op.create_table(
        "playlists",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("image_url", sa.Text, nullable=True),
        sa.Column("is_public", sa.Boolean, default=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- playlist_tracks ---
    op.create_table(
        "playlist_tracks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("playlist_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("playlists.id", ondelete="CASCADE"), nullable=False),
        sa.Column("track_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tracks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("position", sa.Integer, nullable=False),
        sa.Column("added_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- favorites ---
    op.create_table(
        "favorites",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_type", sa.String(20), nullable=False),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # --- digging_history ---
    op.create_table(
        "digging_history",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("target_type", sa.String(50), nullable=True),
        sa.Column("target_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("query", sa.String(500), nullable=True),
        sa.Column("platform", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("digging_history")
    op.drop_table("favorites")
    op.drop_table("playlist_tracks")
    op.drop_table("playlists")
    op.drop_table("users")
    op.drop_table("track_sources")
    op.drop_table("track_artists")
    op.drop_table("tracks")
    op.drop_table("dedup_groups")
    op.drop_table("albums")
    op.drop_table("artist_platform_ids")
    op.drop_table("artist_aliases")
    op.drop_table("artists")
    op.execute("DROP EXTENSION IF EXISTS pg_trgm")
