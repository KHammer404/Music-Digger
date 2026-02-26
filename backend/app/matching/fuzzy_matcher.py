"""Fuzzy string matching for artist and track name comparison."""

from thefuzz import fuzz

from app.matching.name_normalizer import normalize_name


def artist_name_similarity(name_a: str, name_b: str) -> float:
    """Compare two artist names and return similarity score (0.0 ~ 1.0)."""
    norm_a = normalize_name(name_a)
    norm_b = normalize_name(name_b)

    if not norm_a or not norm_b:
        return 0.0

    # Exact match after normalization
    if norm_a == norm_b:
        return 1.0

    # Token sort ratio handles word order differences
    # e.g., "IOSYS feat. ななひら" vs "ななひら feat. IOSYS"
    token_sort = fuzz.token_sort_ratio(norm_a, norm_b) / 100.0

    # Partial ratio handles substring matches
    # e.g., "ななひら" vs "ななひら (Nanahira)"
    partial = fuzz.partial_ratio(norm_a, norm_b) / 100.0

    # Weighted combination
    return max(token_sort, partial * 0.9)


def track_title_similarity(title_a: str, title_b: str) -> float:
    """Compare two track titles and return similarity score (0.0 ~ 1.0)."""
    norm_a = normalize_name(title_a)
    norm_b = normalize_name(title_b)

    if not norm_a or not norm_b:
        return 0.0

    if norm_a == norm_b:
        return 1.0

    return fuzz.token_sort_ratio(norm_a, norm_b) / 100.0


def is_same_artist(name_a: str, name_b: str, threshold: float = 0.85) -> bool:
    """Check if two names likely refer to the same artist."""
    return artist_name_similarity(name_a, name_b) >= threshold


def is_same_track(
    title_a: str,
    title_b: str,
    duration_a: int | None,
    duration_b: int | None,
    artist_a: str = "",
    artist_b: str = "",
    title_threshold: float = 0.82,
    duration_tolerance: int = 5,
) -> bool:
    """Check if two tracks are likely the same song.

    Criteria:
    1. Title similarity >= threshold (default 0.82)
    2. Duration difference <= tolerance seconds (default 5s)
    3. Artist overlap (if provided)
    """
    title_sim = track_title_similarity(title_a, title_b)
    if title_sim < title_threshold:
        return False

    # Check duration if both available
    if duration_a is not None and duration_b is not None:
        if abs(duration_a - duration_b) > duration_tolerance:
            return False

    # Check artist overlap if provided
    if artist_a and artist_b:
        artist_sim = artist_name_similarity(artist_a, artist_b)
        if artist_sim < 0.5:
            return False

    return True
