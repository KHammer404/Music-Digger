import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music_digger/presentation/widgets/source_badge.dart';
import 'package:music_digger/presentation/blocs/home/home_state.dart';
import 'package:music_digger/presentation/blocs/library/library_state.dart';
import 'package:music_digger/presentation/blocs/export/export_state.dart';

void main() {
  group('SourceBadge', () {
    testWidgets('renders YouTube badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SourceBadge(platform: 'youtube', size: 24)),
        ),
      );

      expect(find.text('YT'), findsOneWidget);
    });

    testWidgets('renders Spotify badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SourceBadge(platform: 'spotify', size: 24)),
        ),
      );

      expect(find.text('SP'), findsOneWidget);
    });

    test('displayName returns correct names', () {
      expect(SourceBadge.displayName('youtube'), 'YouTube');
      expect(SourceBadge.displayName('spotify'), 'Spotify');
      expect(SourceBadge.displayName('niconico'), 'NicoNico');
      expect(SourceBadge.displayName('soundcloud'), 'SoundCloud');
      expect(SourceBadge.displayName('bandcamp'), 'Bandcamp');
      expect(SourceBadge.displayName('vocadb'), 'VocaDB');
      expect(SourceBadge.displayName('musicbrainz'), 'MusicBrainz');
      expect(SourceBadge.displayName('lastfm'), 'Last.fm');
      expect(SourceBadge.displayName('unknown'), 'unknown');
    });
  });

  group('RecommendedArtist', () {
    test('fromJson creates correct instance', () {
      final json = {
        'name': 'Nanahira',
        'image_url': 'https://example.com/img.jpg',
        'platform': 'vocadb',
        'platform_id': '123',
        'url': 'https://vocadb.net/Ar/123',
        'match_score': 0.85,
      };

      final artist = RecommendedArtist.fromJson(json);

      expect(artist.name, 'Nanahira');
      expect(artist.imageUrl, 'https://example.com/img.jpg');
      expect(artist.platform, 'vocadb');
      expect(artist.platformId, '123');
      expect(artist.matchScore, 0.85);
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};

      final artist = RecommendedArtist.fromJson(json);

      expect(artist.name, '');
      expect(artist.imageUrl, isNull);
      expect(artist.platform, '');
      expect(artist.matchScore, 0.0);
    });
  });

  group('HomeState', () {
    test('initial state is correct', () {
      const state = HomeState();
      expect(state.status, HomeStatus.initial);
      expect(state.discoveries, isEmpty);
      expect(state.similarArtists, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      const original = HomeState(
        status: HomeStatus.loaded,
        discoveries: [],
      );

      final updated = original.copyWith(
        similarArtists: [
          const RecommendedArtist(
            name: 'Test',
            platform: 'youtube',
            platformId: '1',
          ),
        ],
      );

      expect(updated.status, HomeStatus.loaded);
      expect(updated.similarArtists.length, 1);
    });
  });

  group('LibraryState', () {
    test('initial state is correct', () {
      const state = LibraryState();
      expect(state.status, LibraryStatus.initial);
      expect(state.playlists, isEmpty);
      expect(state.favorites, isEmpty);
      expect(state.history, isEmpty);
    });

    test('PlaylistItem equality', () {
      const a = PlaylistItem(id: '1', name: 'Test', trackCount: 5);
      const b = PlaylistItem(id: '1', name: 'Test', trackCount: 5);
      expect(a, equals(b));
    });

    test('HistoryItem equality', () {
      const a = HistoryItem(id: '1', action: 'search', createdAt: '2025-01-01');
      const b = HistoryItem(id: '1', action: 'search', createdAt: '2025-01-01');
      expect(a, equals(b));
    });
  });

  group('ExportState', () {
    test('initial state is idle', () {
      const state = ExportState();
      expect(state.status, ExportStatus.idle);
      expect(state.message, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith works correctly', () {
      const state = ExportState();
      final updated = state.copyWith(
        status: ExportStatus.exported,
        message: 'Done',
      );
      expect(updated.status, ExportStatus.exported);
      expect(updated.message, 'Done');
    });
  });
}
