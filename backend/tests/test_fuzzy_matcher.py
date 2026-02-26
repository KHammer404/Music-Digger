"""Tests for fuzzy matching."""

import pytest

from app.matching.fuzzy_matcher import (
    artist_name_similarity,
    track_title_similarity,
    is_same_track,
)


class TestArtistNameSimilarity:
    def test_exact_match(self):
        score = artist_name_similarity("Nanahira", "Nanahira")
        assert score >= 0.99

    def test_case_insensitive(self):
        score = artist_name_similarity("nanahira", "Nanahira")
        assert score >= 0.95

    def test_different_names(self):
        score = artist_name_similarity("Nanahira", "IOSYS")
        assert score < 0.5

    def test_similar_names(self):
        score = artist_name_similarity("Nanahira", "Nanahiira")
        assert score > 0.8


class TestTrackTitleSimilarity:
    def test_exact_match(self):
        score = track_title_similarity("Happy Song", "Happy Song")
        assert score >= 0.99

    def test_similar_titles(self):
        score = track_title_similarity("Happy Song", "Happy Song (Remix)")
        assert score > 0.6

    def test_different_titles(self):
        score = track_title_similarity("Song A", "Completely Different")
        assert score < 0.5


class TestIsSameTrack:
    def test_same_track(self):
        # Uses actual parameter names: title_a, title_b, duration_a, duration_b
        assert is_same_track(
            title_a="My Song", title_b="My Song",
            duration_a=240, duration_b=241,
            artist_a="Artist", artist_b="Artist",
        )

    def test_different_tracks(self):
        assert not is_same_track(
            title_a="Song A", title_b="Song B",
            duration_a=240, duration_b=300,
            artist_a="Artist A", artist_b="Artist B",
        )

    def test_same_title_different_duration(self):
        # More than 5 seconds apart should not match
        assert not is_same_track(
            title_a="My Song", title_b="My Song",
            duration_a=240, duration_b=300,
            artist_a="Artist", artist_b="Artist",
        )

    def test_no_duration_still_matches_title(self):
        assert is_same_track(
            title_a="My Song", title_b="My Song",
            duration_a=None, duration_b=None,
            artist_a="Artist", artist_b="Artist",
        )

    def test_different_artist_same_title(self):
        # Same title but very different artists should not match
        assert not is_same_track(
            title_a="Love", title_b="Love",
            duration_a=240, duration_b=241,
            artist_a="Taylor Swift", artist_b="IOSYS",
        )
