"""CJK romanization for cross-language name matching.

Converts Japanese (kana/kanji), Korean (hangul), and Chinese characters
to romanized forms for comparison.
"""

import unicodedata

from unidecode import unidecode

from app.matching.name_normalizer import normalize_name

# Lazy imports for optional heavy dependencies
_kakasi = None
_jamo = None


def _get_kakasi():
    global _kakasi
    if _kakasi is None:
        try:
            import pykakasi
            kks = pykakasi.kakasi()
            _kakasi = kks
        except ImportError:
            _kakasi = False
    return _kakasi if _kakasi is not False else None


def _get_jamo():
    global _jamo
    if _jamo is None:
        try:
            import jamo as jamo_module
            _jamo = jamo_module
        except ImportError:
            _jamo = False
    return _jamo if _jamo is not False else None


def contains_japanese(text: str) -> bool:
    """Check if text contains Japanese characters (hiragana/katakana/kanji)."""
    for char in text:
        cp = ord(char)
        if (0x3040 <= cp <= 0x309F or   # Hiragana
            0x30A0 <= cp <= 0x30FF or   # Katakana
            0x4E00 <= cp <= 0x9FFF):    # CJK Unified Ideographs
            return True
    return False


def contains_korean(text: str) -> bool:
    """Check if text contains Korean characters (Hangul)."""
    for char in text:
        cp = ord(char)
        if (0xAC00 <= cp <= 0xD7AF or   # Hangul Syllables
            0x1100 <= cp <= 0x11FF or   # Hangul Jamo
            0x3130 <= cp <= 0x318F):    # Hangul Compatibility Jamo
            return True
    return False


def romanize_japanese(text: str) -> str:
    """Convert Japanese text to romanized form using pykakasi."""
    kakasi = _get_kakasi()
    if not kakasi:
        return unidecode(text)

    result = kakasi.convert(text)
    romanized_parts = []
    for item in result:
        romanized_parts.append(item.get("hepburn", item.get("orig", "")))

    return " ".join(romanized_parts).strip()


def romanize_korean(text: str) -> str:
    """Convert Korean text to approximate romanized form."""
    jamo_mod = _get_jamo()
    if jamo_mod:
        try:
            decomposed = jamo_mod.h2l(text)
            return unidecode(decomposed)
        except Exception:
            pass
    return unidecode(text)


def romanize(text: str) -> str:
    """Romanize any CJK text to ASCII for matching purposes.

    Pipeline:
    1. Unicode NFKC normalization
    2. Detect language
    3. Apply appropriate romanization
    4. Lowercase + strip
    """
    if not text:
        return ""

    normalized = unicodedata.normalize("NFKC", text)

    if contains_japanese(normalized):
        result = romanize_japanese(normalized)
    elif contains_korean(normalized):
        result = romanize_korean(normalized)
    else:
        result = unidecode(normalized)

    return result.lower().strip()


def romanize_and_normalize(text: str) -> str:
    """Full pipeline: romanize then normalize for matching."""
    romanized = romanize(text)
    return normalize_name(romanized)


def names_match_cross_language(name_a: str, name_b: str) -> bool:
    """Check if two names match across different languages/scripts.

    Example:
    - "ななひら" and "Nanahira" → True
    - "나나히라" and "Nanahira" → True (approximate)
    """
    rom_a = romanize_and_normalize(name_a)
    rom_b = romanize_and_normalize(name_b)

    if not rom_a or not rom_b:
        return False

    if rom_a == rom_b:
        return True

    # Use fuzzy matching for romanization approximations
    from app.matching.fuzzy_matcher import artist_name_similarity
    return artist_name_similarity(rom_a, rom_b) >= 0.80
