import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/home/home_event.dart';
import '../blocs/home/home_state.dart';
import '../widgets/error_view.dart';
import '../widgets/source_badge.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(getIt<ApiClient>())..add(const HomeLoadRequested()),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Music Digger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<HomeBloc>().add(const HomeLoadRequested());
            },
          ),
        ],
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return switch (state.status) {
            HomeStatus.initial || HomeStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
            HomeStatus.error => ErrorView(
                error: state.error ?? state.errorMessage ?? 'Error',
                onRetry: () => context.read<HomeBloc>().add(const HomeLoadRequested()),
              ),
            HomeStatus.loaded => _HomeContent(state: state),
          };
        },
      ),
    );
  }
}


class _HomeContent extends StatelessWidget {
  final HomeState state;
  const _HomeContent({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.discoveries.isEmpty && state.similarArtists.isEmpty) {
      return const _EmptyHome();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeBloc>().add(const HomeLoadRequested());
      },
      child: ListView(
        children: [
          // Hero banner
          const _HeroBanner(),

          // Crosslink input
          const _CrosslinkInput(),

          // Discoveries / Trending section
          if (state.discoveries.isNotEmpty) ...[
            _SectionHeader(
              title: 'Discover',
              subtitle: 'Artists you might like',
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.discoveries.length,
                itemBuilder: (context, index) {
                  final artist = state.discoveries[index];
                  return _ArtistCard(artist: artist);
                },
              ),
            ),
          ],

          // Similar artists section (if loaded)
          if (state.similarArtists.isNotEmpty) ...[
            _SectionHeader(
              title: 'Similar to ${state.similarArtistsFor ?? ""}',
              subtitle: 'Based on your recent activity',
            ),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.similarArtists.length,
                itemBuilder: (context, index) {
                  final artist = state.similarArtists[index];
                  return _ArtistCard(artist: artist);
                },
              ),
            ),
          ],

          // Quick actions
          const _QuickActions(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note, size: 80, color: Color(0xFF6C5CE7)),
          const SizedBox(height: 24),
          const Text(
            'Music Digger',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Discover music across 8 platforms',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: () => context.go('/search'),
            icon: const Icon(Icons.search),
            label: const Text('Start Searching'),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF00B894)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dig Deeper',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find hidden tracks across YouTube, Spotify, NicoNico, and 5 more platforms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(200),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/search'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF6C5CE7),
            ),
            child: const Text('Search Artists'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final RecommendedArtist artist;
  const _ArtistCard({required this.artist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/artist/${artist.platform}:${artist.platformId}');
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            // Artist image
            Container(
              width: 110,
              height: 110,
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
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 8),
            // Artist name
            Text(
              artist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            // Platform badge
            SourceBadge(platform: artist.platform, size: 16),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Platforms',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PlatformChip(platform: 'youtube', label: 'YouTube'),
              _PlatformChip(platform: 'spotify', label: 'Spotify'),
              _PlatformChip(platform: 'niconico', label: 'NicoNico'),
              _PlatformChip(platform: 'soundcloud', label: 'SoundCloud'),
              _PlatformChip(platform: 'bandcamp', label: 'Bandcamp'),
              _PlatformChip(platform: 'vocadb', label: 'VocaDB'),
              _PlatformChip(platform: 'musicbrainz', label: 'MusicBrainz'),
              _PlatformChip(platform: 'lastfm', label: 'Last.fm'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CrosslinkInput extends StatelessWidget {
  const _CrosslinkInput();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/crosslink'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withAlpha(50)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, color: Color(0xFF6C5CE7), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Paste a music link to find it everywhere...',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String platform;
  final String label;
  const _PlatformChip({required this.platform, required this.label});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: SourceBadge(platform: platform, size: 18),
      label: Text(label),
      onPressed: () {
        // Navigate to search with platform pre-selected
        context.go('/search');
      },
    );
  }
}
