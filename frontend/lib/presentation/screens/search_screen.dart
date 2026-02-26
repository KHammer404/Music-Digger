import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/search_repository.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/search/search_event.dart';
import '../blocs/search/search_state.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/source_badge.dart';
import '../widgets/track_tile.dart';
import 'artist_detail_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(getIt<SearchRepository>()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search artists, tracks...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchBloc>().add(const SearchCleared());
                  },
                ),
              ),
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) {
                  context.read<SearchBloc>().add(SearchSubmitted(query));
                }
              },
            ),
          ),

          // Platform filter chips
          BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (prev, curr) =>
                prev.selectedPlatforms != curr.selectedPlatforms,
            builder: (context, state) {
              return SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final platform in _platforms)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(SourceBadge.displayName(platform)),
                          selected: state.selectedPlatforms.contains(platform),
                          onSelected: (_) {
                            context
                                .read<SearchBloc>()
                                .add(SearchPlatformToggled(platform));
                          },
                          selectedColor:
                              const Color(0xFF6C5CE7).withAlpha(50),
                          checkmarkColor: const Color(0xFF6C5CE7),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Results
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                return switch (state.status) {
                  SearchStatus.initial => const _EmptyState(),
                  SearchStatus.loading => const TrackListShimmer(),
                  SearchStatus.error => ErrorView(
                      error: state.error ?? state.errorMessage ?? 'An error occurred',
                      onRetry: state.query.isNotEmpty
                          ? () => context.read<SearchBloc>().add(SearchSubmitted(state.query))
                          : null,
                    ),
                  SearchStatus.loaded => state.hasResults
                      ? _ResultsList(state: state)
                      : const _NoResultsState(),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _platforms = [
    'youtube',
    'spotify',
    'niconico',
    'soundcloud',
    'bandcamp',
    'vocadb',
    'musicbrainz',
    'lastfm',
  ];
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Search for artists or tracks',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Try "ななひら", "Nanahira", or "나나히라"',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No results found', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}


class _ResultsList extends StatefulWidget {
  final SearchState state;
  const _ResultsList({required this.state});

  @override
  State<_ResultsList> createState() => _ResultsListState();
}

class _ResultsListState extends State<_ResultsList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isNearBottom) {
      context.read<SearchBloc>().add(const SearchLoadMore());
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= maxScroll - 200;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return ListView(
      controller: _scrollController,
      children: [
        // Artists section
        if (state.artists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Artists (${state.totalArtists})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: state.artists.length,
              itemBuilder: (context, index) {
                final artist = state.artists[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArtistDetailScreen(artistId: artist.id),
                      ),
                    );
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: artist.imageUrl != null
                              ? NetworkImage(artist.imageUrl!)
                              : null,
                          child: artist.imageUrl == null
                              ? const Icon(Icons.person, size: 36)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          artist.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
        ],

        // Tracks section
        if (state.tracks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Tracks (${state.totalTracks})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (var i = 0; i < state.tracks.length; i++)
            AnimatedListItem(
              index: i,
              child: TrackTile(
                track: state.tracks[i],
                onTap: () {
                  context.read<PlayerBloc>().add(PlayerPlayTrack(state.tracks[i]));
                },
              ),
            ),
        ],

        // Loading more indicator
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),

        // Bottom padding for mini player
        const SizedBox(height: 80),
      ],
    );
  }
}
