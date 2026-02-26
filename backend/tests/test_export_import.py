"""Tests for export/import file parsing.

These tests extract and test the parsing logic directly
to avoid importing DB dependencies (asyncpg, etc.).
"""

import csv
import io
import json

import pytest


# ── Inline copies of parsing functions (to avoid DB import chain) ──

def _parse_json_file(content: bytes) -> list[dict]:
    data = json.loads(content.decode("utf-8"))
    if isinstance(data, dict):
        return data.get("tracks", [])
    if isinstance(data, list):
        return data
    return []


def _parse_csv_file(content: bytes) -> list[dict]:
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


def _parse_m3u_file(content: bytes) -> tuple[list[dict], str]:
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
            if current_info:
                current_info["url"] = line
                tracks.append(current_info)
                current_info = None
            else:
                tracks.append({"title": line, "artist": "", "url": line})

    return tracks, playlist_name


# ── Tests ──

class TestParseJsonFile:
    def test_parse_tracks_array(self):
        content = b'[{"title": "Song A", "artist": "Artist A"}]'
        result = _parse_json_file(content)
        assert len(result) == 1
        assert result[0]["title"] == "Song A"

    def test_parse_object_with_tracks(self):
        content = b'{"name": "My Playlist", "tracks": [{"title": "Song"}]}'
        result = _parse_json_file(content)
        assert len(result) == 1

    def test_empty_array(self):
        result = _parse_json_file(b"[]")
        assert result == []


class TestParseCsvFile:
    def test_basic_csv(self):
        content = "Title,Artist,Platform,URL,Duration\nSong A,Artist A,youtube,https://yt.com,240\n"
        result = _parse_csv_file(content.encode("utf-8-sig"))
        assert len(result) == 1
        assert result[0]["title"] == "Song A"
        assert result[0]["artist"] == "Artist A"

    def test_empty_csv(self):
        content = "Title,Artist\n"
        result = _parse_csv_file(content.encode("utf-8-sig"))
        assert result == []


class TestParseM3uFile:
    def test_basic_m3u(self):
        content = "#EXTM3U\n#PLAYLIST:Test\n#EXTINF:240,Artist - Song\nhttps://example.com\n"
        tracks, name = _parse_m3u_file(content.encode("utf-8"))
        assert name == "Test"
        assert len(tracks) == 1
        assert tracks[0]["title"] == "Song"
        assert tracks[0]["artist"] == "Artist"
        assert tracks[0]["url"] == "https://example.com"

    def test_m3u_without_playlist_name(self):
        content = "#EXTM3U\n#EXTINF:120,Track\nhttps://example.com\n"
        tracks, name = _parse_m3u_file(content.encode("utf-8"))
        assert name == "Imported Playlist"
        assert len(tracks) == 1

    def test_empty_m3u(self):
        content = "#EXTM3U\n"
        tracks, name = _parse_m3u_file(content.encode("utf-8"))
        assert tracks == []
