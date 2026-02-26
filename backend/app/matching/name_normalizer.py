"""Name normalization pipeline for cross-platform artist/track matching.

Handles CJK characters, romanization, and various naming conventions
used across different music platforms.
"""

import re
import unicodedata


# Common feat/collaboration patterns across languages
FEAT_PATTERNS = re.compile(
    r'\s*[\(\[（【]?\s*'
    r'(?:feat\.?|ft\.?|featuring|with|w/|×|x|&|prod\.?|produced by|cv[.:]?)'
    r'\s*[\)\]）】]?',
    re.IGNORECASE,
)

# Bracket content patterns
BRACKET_PATTERN = re.compile(r'[\(\[（【][^)\]）】]*[\)\]）】]')

# Common suffixes to strip
SUFFIX_PATTERNS = re.compile(
    r'\s*[-–—]\s*(?:official|music|video|mv|pv|full|ver\.?|version|remix|cover|歌ってみた|踊ってみた|original)\s*$',
    re.IGNORECASE,
)

# Whitespace normalization
MULTI_SPACE = re.compile(r'\s+')


def normalize_name(name: str) -> str:
    """Full normalization pipeline for matching purposes.

    Steps:
    1. Unicode NFKC normalization
    2. Lowercase
    3. Strip whitespace and special chars
    4. Remove common suffixes
    """
    if not name:
        return ""

    # Step 1: Unicode NFKC normalization (handles fullwidth chars, etc.)
    result = unicodedata.normalize("NFKC", name)

    # Step 2: Lowercase
    result = result.lower()

    # Step 3: Remove common suffixes
    result = SUFFIX_PATTERNS.sub("", result)

    # Step 4: Normalize whitespace
    result = MULTI_SPACE.sub(" ", result).strip()

    return result


def normalize_for_search(name: str) -> str:
    """Lighter normalization for search queries."""
    if not name:
        return ""
    result = unicodedata.normalize("NFKC", name)
    result = result.lower().strip()
    result = MULTI_SPACE.sub(" ", result)
    return result


def split_artist_names(text: str) -> list[str]:
    """Split a string containing multiple artist names.

    Handles patterns like:
    - "Artist1 feat. Artist2"
    - "Artist1 & Artist2"
    - "Artist1 × Artist2"
    - "Artist1, Artist2"
    """
    if not text:
        return []

    # First, extract bracket content as potential additional artists
    bracket_artists = []
    for match in BRACKET_PATTERN.finditer(text):
        content = match.group()[1:-1].strip()
        # Check if bracket contains feat-like pattern
        feat_match = FEAT_PATTERNS.search(content)
        if feat_match:
            artist_part = content[feat_match.end():].strip()
            if artist_part:
                bracket_artists.extend(_split_by_separators(artist_part))

    # Remove bracket content from main text
    main_text = BRACKET_PATTERN.sub("", text).strip()

    # Split by feat patterns
    parts = FEAT_PATTERNS.split(main_text)
    artists = []

    for part in parts:
        part = part.strip()
        if part:
            # Further split by comma and &
            artists.extend(_split_by_separators(part))

    artists.extend(bracket_artists)

    # Clean up and deduplicate while preserving order
    seen = set()
    result = []
    for artist in artists:
        cleaned = artist.strip().strip(",").strip()
        normalized = normalize_name(cleaned)
        if cleaned and normalized not in seen:
            seen.add(normalized)
            result.append(cleaned)

    return result


def _split_by_separators(text: str) -> list[str]:
    """Split by common separators (comma, &, ×)."""
    parts = re.split(r'\s*[,、]\s*|\s+[&×x]\s+', text, flags=re.IGNORECASE)
    return [p.strip() for p in parts if p.strip()]


def extract_title_and_artist(video_title: str) -> tuple[str, str | None]:
    """Extract track title and artist from a YouTube-style video title.

    Common patterns:
    - "Artist - Title"
    - "Artist 「Title」"
    - "Title / Artist"
    - "【Artist】Title"
    """
    if not video_title:
        return ("", None)

    title = video_title.strip()

    # Pattern: 【Artist】Title or 「Artist」Title
    cjk_bracket = re.match(r'[【「]([^】」]+)[】」]\s*(.*)', title)
    if cjk_bracket:
        return (cjk_bracket.group(2).strip(), cjk_bracket.group(1).strip())

    # Pattern: Artist - Title (most common)
    dash_split = re.split(r'\s*[-–—]\s*', title, maxsplit=1)
    if len(dash_split) == 2 and len(dash_split[0]) > 0 and len(dash_split[1]) > 0:
        return (dash_split[1].strip(), dash_split[0].strip())

    # Pattern: Title / Artist
    slash_split = re.split(r'\s*/\s*', title, maxsplit=1)
    if len(slash_split) == 2:
        return (slash_split[0].strip(), slash_split[1].strip())

    return (title, None)
