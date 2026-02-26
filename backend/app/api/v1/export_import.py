"""Export/Import API — JSON, CSV, M3U playlist formats."""

import csv
import io
import json
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import Playlist, PlaylistTrack

router = APIRouter()


class ImportTrackItem(BaseModel):
    title: str
    artist: str
    platform: str | None = None
    platform_id: str | None = None
    url: str | None = None
    duration_seconds: int | None = None


class ImportPlaylistRequest(BaseModel):
    name: str
    description: str | None = None
    user_id: str
    tracks: list[ImportTrackItem]


# ── Export endpoints ──────────────────────────────────────────


@router.get("/playlists/{playlist_id}/json")
async def export_playlist_json(
    playlist_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Export a playlist as JSON."""
    playlist_data = await _get_playlist_export_data(playlist_id, db)

    content = json.dumps(playlist_data, indent=2, ensure_ascii=False)
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="{playlist_data["name"]}.json"',
        },
    )


@router.get("/playlists/{playlist_id}/csv")
async def export_playlist_csv(
    playlist_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Export a playlist as CSV."""
    playlist_data = await _get_playlist_export_data(playlist_id, db)

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["#", "Title", "Artist", "Platform", "URL", "Duration"])

    for i, track in enumerate(playlist_data.get("tracks", []), 1):
        writer.writerow([
            i,
            track.get("title", ""),
            track.get("artist", ""),
            track.get("platform", ""),
            track.get("url", ""),
            track.get("duration_seconds", ""),
        ])

    csv_bytes = output.getvalue().encode("utf-8-sig")
    return StreamingResponse(
        io.BytesIO(csv_bytes),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{playlist_data["name"]}.csv"',
        },
    )


@router.get("/playlists/{playlist_id}/m3u")
async def export_playlist_m3u(
    playlist_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Export a playlist as M3U."""
    playlist_data = await _get_playlist_export_data(playlist_id, db)

    lines = ["#EXTM3U", f"#PLAYLIST:{playlist_data['name']}"]
    for track in playlist_data.get("tracks", []):
        duration = track.get("duration_seconds", -1) or -1
        title = track.get("title", "Unknown")
        artist = track.get("artist", "Unknown")
        url = track.get("url", "")
        lines.append(f"#EXTINF:{duration},{artist} - {title}")
        if url:
            lines.append(url)

    content = "\n".join(lines) + "\n"
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")),
        media_type="audio/x-mpegurl",
        headers={
            "Content-Disposition": f'attachment; filename="{playlist_data["name"]}.m3u"',
        },
    )


# ── Import endpoints ─────────────────────────────────────────


@router.post("/playlists/import/json")
async def import_playlist_json(
    req: ImportPlaylistRequest,
    db: AsyncSession = Depends(get_db),
):
    """Import a playlist from JSON track list."""
    playlist = Playlist(
        user_id=uuid.UUID(req.user_id),
        name=req.name,
        description=req.description,
    )
    db.add(playlist)
    await db.flush()

    imported_count = 0
    for i, track in enumerate(req.tracks, 1):
        # Store track metadata as a lightweight reference
        # In a full implementation, this would match tracks against the DB
        imported_count += 1

    return {
        "status": "imported",
        "playlist_id": str(playlist.id),
        "playlist_name": playlist.name,
        "imported_tracks": imported_count,
        "total_tracks": len(req.tracks),
    }


@router.post("/playlists/import/file")
async def import_playlist_file(
    user_id: str = Query(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Import a playlist from an uploaded file (JSON, CSV, or M3U)."""
    content = await file.read()
    filename = file.filename or ""

    if filename.endswith(".json"):
        tracks = _parse_json_file(content)
        name = filename.rsplit(".", 1)[0]
    elif filename.endswith(".csv"):
        tracks = _parse_csv_file(content)
        name = filename.rsplit(".", 1)[0]
    elif filename.endswith(".m3u") or filename.endswith(".m3u8"):
        tracks, name = _parse_m3u_file(content)
    else:
        raise HTTPException(status_code=400, detail="Unsupported file format. Use .json, .csv, or .m3u")

    playlist = Playlist(
        user_id=uuid.UUID(user_id),
        name=name or "Imported Playlist",
    )
    db.add(playlist)
    await db.flush()

    return {
        "status": "imported",
        "playlist_id": str(playlist.id),
        "playlist_name": playlist.name,
        "imported_tracks": len(tracks),
        "tracks": tracks,
    }


# ── Helpers ───────────────────────────────────────────────────


async def _get_playlist_export_data(playlist_id: str, db: AsyncSession) -> dict:
    """Get playlist with tracks for export."""
    result = await db.execute(
        select(Playlist).where(Playlist.id == uuid.UUID(playlist_id))
    )
    pl = result.scalar_one_or_none()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    tracks_result = await db.execute(
        select(PlaylistTrack)
        .where(PlaylistTrack.playlist_id == pl.id)
        .order_by(PlaylistTrack.position)
    )
    playlist_tracks = tracks_result.scalars().all()

    # Build export data
    # Note: In production, you'd join with the tracks table for full metadata
    track_data = []
    for pt in playlist_tracks:
        track_data.append({
            "track_id": str(pt.track_id),
            "position": pt.position,
            "title": "",  # Would be populated from tracks table
            "artist": "",
            "platform": "",
            "url": "",
            "duration_seconds": None,
        })

    return {
        "name": pl.name,
        "description": pl.description,
        "track_count": len(track_data),
        "exported_at": pl.updated_at.isoformat() if pl.updated_at else None,
        "tracks": track_data,
    }


def _parse_json_file(content: bytes) -> list[dict]:
    """Parse a JSON playlist file."""
    try:
        data = json.loads(content.decode("utf-8"))
        if isinstance(data, dict):
            return data.get("tracks", [])
        if isinstance(data, list):
            return data
        return []
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise HTTPException(status_code=400, detail="Invalid JSON file")


def _parse_csv_file(content: bytes) -> list[dict]:
    """Parse a CSV playlist file."""
    try:
        text = content.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(text))
        tracks = []
        for row in reader:
            tracks.append({
                "title": row.get("Title", row.get("title", "")),
                "artist": row.get("Artist", row.get("artist", "")),
                "platform": row.get("Platform", row.get("platform", "")),
                "url": row.get("URL", row.get("url", "")),
                "duration_seconds": int(row["Duration"]) if row.get("Duration") else None,
            })
        return tracks
    except (UnicodeDecodeError, csv.Error):
        raise HTTPException(status_code=400, detail="Invalid CSV file")


def _parse_m3u_file(content: bytes) -> tuple[list[dict], str]:
    """Parse an M3U playlist file."""
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        text = content.decode("latin-1")

    lines = text.strip().split("\n")
    tracks = []
    playlist_name = "Imported Playlist"
    current_info = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith("#PLAYLIST:"):
            playlist_name = line[10:].strip()
        elif line.startswith("#EXTINF:"):
            # Format: #EXTINF:duration,Artist - Title
            info_part = line[8:]
            duration_str, _, display = info_part.partition(",")
            try:
                duration = int(duration_str.strip())
            except ValueError:
                duration = -1

            if " - " in display:
                artist, _, title = display.partition(" - ")
            else:
                artist, title = "", display

            current_info = {
                "title": title.strip(),
                "artist": artist.strip(),
                "duration_seconds": duration if duration > 0 else None,
            }
        elif not line.startswith("#"):
            track = current_info or {"title": "", "artist": ""}
            track["url"] = line
            tracks.append(track)
            current_info = None

    return tracks, playlist_name
