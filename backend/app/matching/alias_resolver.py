"""Alias resolver — resolves artist identities across platforms using VocaDB anchoring."""

from app.cache.redis_cache import cache_get, cache_set
from app.matching.cjk_romanizer import romanize_and_normalize, names_match_cross_language
from app.matching.fuzzy_matcher import artist_name_similarity
from app.sources.base import SourceArtist

ALIAS_CACHE_TTL = 86400  # 24 hours


class AliasResolver:
    """Resolves whether artists across different platforms are the same person.

    Strategy:
    1. VocaDB anchoring — if VocaDB has aliases, use them as ground truth
    2. Romanization matching — cross-language comparison
    3. Fuzzy matching — for spelling variations
    """

    def __init__(self, vocadb_adapter=None):
        self._vocadb = vocadb_adapter

    async def resolve_aliases(self, artist_name: str) -> list[str]:
        """Get all known aliases for an artist name.

        Returns a list of aliases from VocaDB + romanization variants.
        """
        cache_key = f"aliases:{romanize_and_normalize(artist_name)}"
        cached = await cache_get(cache_key)
        if cached is not None:
            return cached

        aliases = {artist_name}

        # Try VocaDB lookup
        if self._vocadb:
            vocadb_artists = await self._vocadb.search_artists(artist_name, limit=3)
            for va in vocadb_artists:
                if artist_name_similarity(va.name, artist_name) >= 0.8 or \
                   names_match_cross_language(va.name, artist_name):
                    aliases.add(va.name)
                    aliases.update(va.aliases)

                    # Get detailed aliases from VocaDB
                    detailed = await self._vocadb.get_artist_aliases(va.platform_id)
                    for alias_info in detailed:
                        if alias_info.get("name"):
                            aliases.add(alias_info["name"])

        result = list(aliases)
        await cache_set(cache_key, result, ALIAS_CACHE_TTL)
        return result

    def are_same_artist(self, artist_a: SourceArtist, artist_b: SourceArtist) -> bool:
        """Check if two SourceArtist objects refer to the same person.

        Matching layers:
        1. Normalized name exact match
        2. Cross-language romanization match
        3. Alias overlap
        4. Fuzzy name match
        """
        # Layer 1: Normalized exact match
        from app.matching.name_normalizer import normalize_name
        norm_a = normalize_name(artist_a.name)
        norm_b = normalize_name(artist_b.name)
        if norm_a == norm_b:
            return True

        # Layer 2: Cross-language romanization
        if names_match_cross_language(artist_a.name, artist_b.name):
            return True

        # Layer 3: Alias overlap
        all_names_a = {artist_a.name} | set(artist_a.aliases)
        all_names_b = {artist_b.name} | set(artist_b.aliases)
        for na in all_names_a:
            for nb in all_names_b:
                if normalize_name(na) == normalize_name(nb):
                    return True
                if names_match_cross_language(na, nb):
                    return True

        # Layer 4: Fuzzy match (stricter threshold)
        if artist_name_similarity(artist_a.name, artist_b.name) >= 0.90:
            return True

        return False

    def group_same_artists(self, artists: list[SourceArtist]) -> list[list[SourceArtist]]:
        """Group a list of artists by identity.

        Returns groups where each group contains artists from different platforms
        that are likely the same person.
        """
        groups: list[list[SourceArtist]] = []

        for artist in artists:
            matched = False
            for group in groups:
                if any(self.are_same_artist(artist, existing) for existing in group):
                    group.append(artist)
                    matched = True
                    break

            if not matched:
                groups.append([artist])

        return groups
