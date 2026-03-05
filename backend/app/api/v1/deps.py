"""Shared dependencies for API endpoints."""

from functools import lru_cache

from app.services.aggregation_service import AggregationService
from app.services.recommendation_service import RecommendationService
from app.sources.bandcamp import BandcampAdapter
from app.sources.lastfm import LastfmAdapter
from app.sources.musicbrainz import MusicBrainzAdapter
from app.sources.niconico import NicoNicoAdapter
from app.sources.soundcloud import SoundCloudAdapter
from app.sources.spotify import SpotifyAdapter
from app.sources.vocadb import VocaDBAdapter
from app.sources.youtube import YouTubeAdapter

# Shared adapter instances
_vocadb = VocaDBAdapter()
_lastfm = LastfmAdapter()
_spotify = SpotifyAdapter()
_youtube = YouTubeAdapter()


@lru_cache
def get_aggregation_service() -> AggregationService:
    """Create aggregation service with all 8 platform adapters."""
    adapters = [
        _youtube,
        _vocadb,
        MusicBrainzAdapter(),
        _spotify,
        NicoNicoAdapter(),
        SoundCloudAdapter(),
        _lastfm,
        BandcampAdapter(),
    ]

    return AggregationService(adapters, vocadb_adapter=_vocadb)


@lru_cache
def get_recommendation_service() -> RecommendationService:
    """Create recommendation service with Last.fm, Spotify, VocaDB."""
    return RecommendationService(
        lastfm=_lastfm,
        spotify=_spotify,
        vocadb=_vocadb,
        youtube=_youtube,
    )
