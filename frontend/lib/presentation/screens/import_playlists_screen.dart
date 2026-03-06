import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/oauth_service.dart';
import '../../core/services/user_service.dart';
import '../blocs/connections/connections_bloc.dart';
import '../blocs/connections/connections_event.dart';
import '../blocs/connections/connections_state.dart';
import '../blocs/import/import_bloc.dart';

class ImportPlaylistsScreen extends StatelessWidget {
  const ImportPlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final oauthService = getIt<OAuthService>();
    final userId = getIt<UserService>().userId;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = ConnectionsBloc(oauthService, userId);
            bloc.add(const ConnectionsLoad());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) => ImportBloc(oauthService, userId),
        ),
      ],
      child: const _ImportView(),
    );
  }
}

class _ImportView extends StatelessWidget {
  const _ImportView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Playlists'),
      ),
      body: BlocConsumer<ImportBloc, ImportState>(
        listener: (context, importState) {
          if (importState.status == ImportStatus.imported) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${importState.importedPlaylistName ?? "Playlist"} imported (${importState.importedTrackCount ?? 0} tracks)',
                ),
              ),
            );
          } else if (importState.status == ImportStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(importState.errorMessage ?? 'Error'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        },
        builder: (context, importState) {
          // Show track preview if loaded
          if (importState.status == ImportStatus.loadingTracks ||
              importState.status == ImportStatus.tracksLoaded) {
            return _TrackPreview(importState: importState);
          }

          // Show playlists if loaded
          if (importState.status == ImportStatus.loadingPlaylists ||
              importState.status == ImportStatus.loaded ||
              importState.status == ImportStatus.importing ||
              importState.status == ImportStatus.imported) {
            if (importState.playlists.isNotEmpty || importState.status == ImportStatus.loadingPlaylists) {
              return _PlaylistList(importState: importState);
            }
          }

          // Default: show platform picker
          return _PlatformPicker();
        },
      ),
    );
  }
}

class _PlatformPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionsBloc, ConnectionsState>(
      builder: (context, state) {
        if (state.status == ConnectionsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        final platforms = [
          _PlatformInfo('spotify', 'Spotify', Icons.music_note, const Color(0xFF1DB954)),
          _PlatformInfo('youtube', 'YouTube', Icons.play_circle_fill, const Color(0xFFFF0000)),
          _PlatformInfo('tidal', 'Tidal', Icons.waves, const Color(0xFF000000)),
        ];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Select a platform to import playlists from',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ...platforms.map((p) {
              final connected = state.isConnected(p.id);
              final conn = state.getConnection(p.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(p.icon, color: p.color, size: 32),
                  title: Text(p.name),
                  subtitle: Text(
                    connected
                        ? 'Connected as ${conn?.displayName ?? p.name}'
                        : 'Not connected',
                  ),
                  trailing: connected
                      ? const Icon(Icons.chevron_right)
                      : TextButton(
                          onPressed: () {
                            context.read<ConnectionsBloc>().add(ConnectionsConnect(p.id));
                          },
                          child: const Text('Connect'),
                        ),
                  onTap: connected
                      ? () {
                          context.read<ImportBloc>().add(ImportLoadPlaylists(p.id));
                        }
                      : null,
                ),
              );
            }),
            if (state.status == ConnectionsStatus.connecting) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Waiting for authorization...\nComplete login in your browser',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _PlaylistList extends StatelessWidget {
  final ImportState importState;
  const _PlaylistList({required this.importState});

  @override
  Widget build(BuildContext context) {
    if (importState.status == ImportStatus.loadingPlaylists) {
      return const Center(child: CircularProgressIndicator());
    }

    if (importState.playlists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_remove, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No playlists found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: importState.playlists.length,
      itemBuilder: (context, index) {
        final pl = importState.playlists[index];
        return ListTile(
          leading: pl.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    pl.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _playlistIcon(),
                  ),
                )
              : _playlistIcon(),
          title: Text(pl.name),
          subtitle: Text('${pl.trackCount} tracks${pl.owner != null ? ' - ${pl.owner}' : ''}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility),
                tooltip: 'Preview tracks',
                onPressed: () {
                  context.read<ImportBloc>().add(
                    ImportPreviewTracks(importState.selectedPlatform!, pl.id),
                  );
                },
              ),
              IconButton(
                icon: importState.status == ImportStatus.importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                tooltip: 'Import',
                onPressed: importState.status == ImportStatus.importing
                    ? null
                    : () {
                        context.read<ImportBloc>().add(
                          ImportExecute(importState.selectedPlatform!, pl.id),
                        );
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _playlistIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.playlist_play, color: Colors.grey),
    );
  }
}

class _TrackPreview extends StatelessWidget {
  final ImportState importState;
  const _TrackPreview({required this.importState});

  @override
  Widget build(BuildContext context) {
    if (importState.status == ImportStatus.loadingTracks) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.read<ImportBloc>().add(const ImportClearPreview());
                },
              ),
              const SizedBox(width: 8),
              Text(
                '${importState.previewTracks.length} tracks',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  context.read<ImportBloc>().add(
                    ImportExecute(
                      importState.selectedPlatform!,
                      importState.previewPlaylistId!,
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Import All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: importState.previewTracks.length,
            itemBuilder: (context, index) {
              final track = importState.previewTracks[index];
              return ListTile(
                leading: track.thumbnailUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          track.thumbnailUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.music_note, size: 40),
                        ),
                      )
                    : const Icon(Icons.music_note, size: 40),
                title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: track.durationSeconds != null
                    ? Text(
                        '${track.durationSeconds! ~/ 60}:${(track.durationSeconds! % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlatformInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const _PlatformInfo(this.id, this.name, this.icon, this.color);
}
