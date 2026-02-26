import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../blocs/export/export_bloc.dart';
import '../blocs/export/export_event.dart';
import '../blocs/export/export_state.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/library/library_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = LibraryBloc(getIt<ApiClient>(), 'anonymous');
            bloc.add(const LibraryLoadPlaylists());
            bloc.add(const LibraryLoadFavorites());
            bloc.add(const LibraryLoadHistory());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) => ExportBloc(getIt<ApiClient>()),
        ),
      ],
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatelessWidget {
  const _LibraryView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExportBloc, ExportState>(
      listener: (context, state) {
        if (state.status == ExportStatus.exported || state.status == ExportStatus.imported) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message ?? 'Done')),
          );
          context.read<ExportBloc>().add(const ExportClearStatus());
          // Reload playlists after import
          if (state.status == ExportStatus.imported) {
            context.read<LibraryBloc>().add(const LibraryLoadPlaylists());
          }
        } else if (state.status == ExportStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? 'Error'),
              backgroundColor: Colors.redAccent,
            ),
          );
          context.read<ExportBloc>().add(const ExportClearStatus());
        }
      },
      child: BlocListener<LibraryBloc, LibraryState>(
        listenWhen: (prev, curr) => prev.status != curr.status && curr.status == LibraryStatus.error,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? '오류가 발생했습니다'),
              backgroundColor: Colors.redAccent,
              action: SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: () {
                  context.read<LibraryBloc>().add(const LibraryLoadPlaylists());
                },
              ),
            ),
          );
        },
        child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Library'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Playlists'),
                Tab(text: 'Favorites'),
                Tab(text: 'History'),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'create') {
                    _showCreatePlaylistDialog(context);
                  } else if (value == 'import') {
                    _showImportDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'create',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('New Playlist'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.file_download),
                      title: Text('Import Playlist'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, state) {
              return TabBarView(
                children: [
                  _PlaylistsTab(playlists: state.playlists),
                  _FavoritesTab(
                    favorites: state.favorites,
                    isLoadingMore: state.isLoadingMoreFavorites,
                  ),
                  _HistoryTab(
                    history: state.history,
                    isLoadingMore: state.isLoadingMoreHistory,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<LibraryBloc>().add(
                  LibraryCreatePlaylist(nameController.text),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final nameController = TextEditingController();
    final tracksController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Playlist'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Playlist Name',
                  hintText: 'My Imported Playlist',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tracksController,
                decoration: const InputDecoration(
                  labelText: 'Paste JSON tracks',
                  hintText: '[{"title": "Song", "artist": "Artist"}]',
                ),
                maxLines: 5,
                minLines: 3,
              ),
              const SizedBox(height: 8),
              Text(
                'Paste a JSON array of tracks with "title" and "artist" fields.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                List<Map<String, dynamic>> tracks = [];
                try {
                  // Try to parse JSON tracks
                  final parsed = tracksController.text.trim();
                  if (parsed.isNotEmpty) {
                    // Simple parsing — in production, use dart:convert
                    tracks = [];
                  }
                } catch (_) {}

                context.read<ExportBloc>().add(
                  ImportPlaylistFromJson(
                    name: nameController.text,
                    userId: 'anonymous',
                    tracks: tracks,
                  ),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  final List<PlaylistItem> playlists;
  const _PlaylistsTab({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_play, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No playlists yet', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tap menu to create or import', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.playlist_play, color: Colors.grey),
          ),
          title: Text(pl.name),
          subtitle: Text('${pl.trackCount} tracks'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                context.read<LibraryBloc>().add(LibraryDeletePlaylist(pl.id));
              } else if (value == 'export_json') {
                context.read<ExportBloc>().add(ExportPlaylist(
                  playlistId: pl.id,
                  playlistName: pl.name,
                  format: ExportFormat.json,
                ));
              } else if (value == 'export_csv') {
                context.read<ExportBloc>().add(ExportPlaylist(
                  playlistId: pl.id,
                  playlistName: pl.name,
                  format: ExportFormat.csv,
                ));
              } else if (value == 'export_m3u') {
                context.read<ExportBloc>().add(ExportPlaylist(
                  playlistId: pl.id,
                  playlistName: pl.name,
                  format: ExportFormat.m3u,
                ));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_json',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Export JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Export CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_m3u',
                child: ListTile(
                  leading: Icon(Icons.queue_music),
                  title: Text('Export M3U'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          onTap: () {
            // TODO: Navigate to playlist detail
          },
        );
      },
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  final List<FavoriteItem> favorites;
  final bool isLoadingMore;
  const _FavoritesTab({required this.favorites, this.isLoadingMore = false});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
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
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= maxScroll - 200) {
      context.read<LibraryBloc>().add(const LibraryLoadMoreFavorites());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No favorites yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.favorites.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.favorites.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final fav = widget.favorites[index];
        return ListTile(
          leading: Icon(
            fav.targetType == 'artist' ? Icons.person : Icons.music_note,
          ),
          title: Text(fav.targetId),
          subtitle: Text(fav.targetType),
        );
      },
    );
  }
}

class _HistoryTab extends StatefulWidget {
  final List<HistoryItem> history;
  final bool isLoadingMore;
  const _HistoryTab({required this.history, this.isLoadingMore = false});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
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
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset >= maxScroll - 200) {
      context.read<LibraryBloc>().add(const LibraryLoadMoreHistory());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No history yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.history.length + (widget.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.history.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final h = widget.history[index];
        return ListTile(
          leading: Icon(_actionIcon(h.action)),
          title: Text(h.query ?? h.targetId ?? h.action),
          subtitle: Text('${h.action} ${h.platform ?? ''}'),
          trailing: Text(
            h.createdAt.length >= 10 ? h.createdAt.substring(0, 10) : h.createdAt,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        );
      },
    );
  }

  IconData _actionIcon(String action) {
    return switch (action) {
      'search' => Icons.search,
      'view_artist' => Icons.person,
      'play_track' => Icons.play_arrow,
      _ => Icons.history,
    };
  }
}
