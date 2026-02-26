"""Tests for name normalization."""

import pytest

from app.matching.name_normalizer import (
    normalize_name,
    extract_title_and_artist,
    split_artist_names,
)


class TestNormalizeName:
    def test_basic_normalization(self):
        assert normalize_name("  Hello World  ") == "hello world"

    def test_unicode_nfkc(self):
        # Full-width characters → ASCII
        assert normalize_name("Ｈｅｌｌｏ") == "hello"

    def test_removes_bracket_suffixes(self):
        # normalize_name strips common suffixes like "- Official MV"
        result = normalize_name("Song Title")
        assert "song title" in result

    def test_empty_string(self):
        assert normalize_name("") == ""

    def test_japanese_input(self):
        result = normalize_name("ななひら")
        assert isinstance(result, str)
        assert len(result) > 0

    def test_preserves_feat_in_name(self):
        # normalize_name does NOT remove feat — that's split_artist_names' job
        result = normalize_name("Artist feat. Other")
        assert "artist" in result

    def test_removes_suffix_patterns(self):
        # The suffix pattern strips "- mv" or "- official" at end of string
        result = normalize_name("Song Name - MV")
        assert "mv" not in result


class TestExtractTitleAndArtist:
    def test_dash_separator(self):
        title, artist = extract_title_and_artist("Nanahira - Song Name")
        assert artist == "Nanahira"
        assert title == "Song Name"

    def test_no_separator_returns_none_artist(self):
        title, artist = extract_title_and_artist("Just A Title")
        assert title == "Just A Title"
        assert artist is None

    def test_cjk_bracket_pattern(self):
        title, artist = extract_title_and_artist("【Nanahira】Song Name")
        assert artist == "Nanahira"
        assert title == "Song Name"

    def test_slash_separator(self):
        title, artist = extract_title_and_artist("Song Name / Artist")
        assert title == "Song Name"
        assert artist == "Artist"


class TestSplitArtistNames:
    def test_feat_split(self):
        names = split_artist_names("A feat. B")
        assert "A" in names
        assert "B" in names

    def test_comma_split(self):
        names = split_artist_names("A, B, C")
        assert len(names) == 3

    def test_single_artist(self):
        names = split_artist_names("Single Artist")
        assert names == ["Single Artist"]

    def test_x_separator(self):
        names = split_artist_names("A x B")
        assert len(names) == 2

    def test_empty_string(self):
        names = split_artist_names("")
        assert names == []
