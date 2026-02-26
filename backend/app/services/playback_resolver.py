"""Playback resolver — resolves playable URLs for tracks across platforms."""

from dataclasses import dataclass

from app.sources.base import SourceTrack


@dataclass
class PlaybackInfo:
    platform: str
    track_id: str
    url: str
    stream_url: str | None = None
    preview_url: str | None = None
    engine: str = "direct"  # direct, youtube, spotify_sdk, webview
    is_playable: bool = True
    requires_auth: bool = False


class PlaybackResolverService:
    """Resolves the best playback method for a track source."""

    def resolve(self, source: SourceTrack) -> PlaybackInfo:
        """Determine playback info for a given track source."""
        platform = source.platform

        if platform == "youtube":
            return PlaybackInfo(
                platform="youtube",
                track_id=source.platform_id,
                url=source.url,
                engine="youtube",  # youtube_explode_dart on client
                is_playable=True,
            )

        if platform == "spotify":
            preview_url = source.extra.get("preview_url") if source.extra else None
            return PlaybackInfo(
                platform="spotify",
                track_id=source.platform_id,
                url=source.url,
                preview_url=preview_url,
                engine="spotify_sdk" if not preview_url else "direct",
                is_playable=True,
                requires_auth=preview_url is None,
            )

        if platform == "soundcloud":
            return PlaybackInfo(
                platform="soundcloud",
                track_id=source.platform_id,
                url=source.url,
                engine="direct",
                is_playable=source.is_playable,
            )

        if platform == "niconico":
            return PlaybackInfo(
                platform="niconico",
                track_id=source.platform_id,
                url=source.url,
                engine="webview",  # NicoNico requires embedded player
                is_playable=True,
            )

        if platform == "bandcamp":
            return PlaybackInfo(
                platform="bandcamp",
                track_id=source.platform_id,
                url=source.url,
                engine="direct",
                is_playable=True,
            )

        # Metadata-only platforms (musicbrainz, lastfm, vocadb)
        return PlaybackInfo(
            platform=platform,
            track_id=source.platform_id,
            url=source.url,
            engine="none",
            is_playable=False,
        )

    def get_best_playback(self, sources: list[SourceTrack]) -> PlaybackInfo | None:
        """From multiple sources, pick the best one for playback."""
        # Priority: Spotify > YouTube > SoundCloud > NicoNico > Bandcamp
        priority = {"spotify": 1, "youtube": 2, "soundcloud": 3, "niconico": 4, "bandcamp": 5}

        playable = [s for s in sources if s.is_playable]
        if not playable:
            return None

        best = min(playable, key=lambda s: priority.get(s.platform, 99))
        return self.resolve(best)
