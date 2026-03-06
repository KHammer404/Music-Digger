import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/search_repository.dart';
import '../blocs/artist/artist_bloc.dart';
import '../blocs/artist/artist_event.dart';
import '../blocs/artist/artist_state.dart';
import '../blocs/home/home_state.dart';
import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_event.dart';
import '../widgets/error_view.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/source_badge.dart';
import '../widgets/track_tile.dart';

class ArtistDetailScreen extends StatelessWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ArtistBloc(getIt<SearchRepository>(), getIt<ApiClient>())
        ..add(ArtistLoadRequested(artistId)),
      child: const _ArtistDetailView(),
    );
  }
}

class _ArtistDetailView extends StatelessWidget {
  const _ArtistDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArtistBloc, ArtistState>(
      builder: (context, state) {
        return Scaffold(
          body: switch (state.status) {
            ArtistStatus.initial || ArtistStatus.loading =>
              const TrackListShimmer(),
            ArtistStatus.error => ErrorView(
                error: state.error ?? state.errorMessage ?? 'Failed to load artist',
                onRetry: () => Navigator.of(context).pop(),
              ),
            ArtistStatus.loaded => _ArtistContent(state: state),
          },
        );
      },
    );
  }
}

class _ArtistContent extends StatefulWidget {
  final ArtistState state;
  const _ArtistContent({required this.state});

  @override
  State<_ArtistContent> createState() => _ArtistContentState();
}

class _ArtistContentState extends State<_ArtistContent> {
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

  static String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (currentScroll >= maxScroll - 200) {
      context.read<ArtistBloc>().add(const ArtistLoadMoreTracks());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final artist = state.artist!;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Hero header
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              artist.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8, color: Colors.black)],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (artist.imageUrl != null)
                  Image.network(
                    artist.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF16213E),
                      child: const Icon(Icons.person, size: 80, color: Colors.grey),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF16213E),
                    child: const Icon(Icons.person, size: 80, color: Colors.grey),
                  ),
                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Artist info
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Platform presences (unified profile)
                if (state.platformPresences.isNotEmpty) ...[
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.platformPresences.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final p = state.platformPresences[index];
                        return Chip(
                          avatar: SourceBadge(platform: p.platform, size: 18),
                          label: Text(
                            p.followerCount != null
                                ? '${_formatCount(p.followerCount!)}'
                                : p.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Aliases
                if (artist.aliases.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: artist.aliases.map((alias) {
                      return Chip(
                        label: Text(alias, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                if (artist.description != null &&
                    artist.description!.isNotEmpty) ...[
                  Text(
                    artist.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Platform track counts (fallback when no unified data)
                if (state.platformPresences.isEmpty && artist.platformTrackCounts.isNotEmpty) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: artist.platformTrackCounts.entries.map((entry) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SourceBadge(platform: entry.key, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value} tracks',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                const Divider(),

                // Track count header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Tracks (${state.totalTracks})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Track list
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = state.tracks[index];
              return TrackTile(
                track: track,
                onTap: () {
                  context.read<PlayerBloc>().add(PlayerPlayTrack(track));
                },
              );
            },
            childCount: state.tracks.length,
          ),
        ),

        // Loading more indicator
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),

        // Similar Artists section
        if (state.similarArtists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Similar Artists',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Artists similar to ${state.artist?.name ?? ""}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.similarArtists.length,
                itemBuilder: (context, index) {
                  final similar = state.similarArtists[index];
                  return _SimilarArtistCard(artist: similar);
                },
              ),
            ),
          ),
        ],

        // Bottom padding
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}

class _SimilarArtistCard extends StatelessWidget {
  final RecommendedArtist artist;
  const _SimilarArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/artist/${artist.platform}:${artist.platformId}');
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                image: artist.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(artist.imageUrl!),
                        fit: BoxFit.cover,
                        onError: (_, _) {},
                      )
                    : null,
              ),
              child: artist.imageUrl == null
                  ? const Icon(Icons.person, size: 32, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            SourceBadge(platform: artist.platform, size: 14),
          ],
        ),
      ),
    );
  }
}
