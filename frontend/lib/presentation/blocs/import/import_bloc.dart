import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/oauth_service.dart';

// --- Events ---

sealed class ImportEvent extends Equatable {
  const ImportEvent();

  @override
  List<Object?> get props => [];
}

class ImportLoadPlaylists extends ImportEvent {
  final String platform;
  const ImportLoadPlaylists(this.platform);

  @override
  List<Object?> get props => [platform];
}

class ImportPreviewTracks extends ImportEvent {
  final String platform;
  final String playlistId;
  const ImportPreviewTracks(this.platform, this.playlistId);

  @override
  List<Object?> get props => [platform, playlistId];
}

class ImportExecute extends ImportEvent {
  final String platform;
  final String playlistId;
  final String? playlistName;
  const ImportExecute(this.platform, this.playlistId, {this.playlistName});

  @override
  List<Object?> get props => [platform, playlistId, playlistName];
}

class ImportClearPreview extends ImportEvent {
  const ImportClearPreview();
}

// --- State ---

enum ImportStatus { initial, loadingPlaylists, loaded, loadingTracks, tracksLoaded, importing, imported, error }

class ImportState extends Equatable {
  final ImportStatus status;
  final String? selectedPlatform;
  final List<ExternalPlaylist> playlists;
  final List<ExternalTrack> previewTracks;
  final String? previewPlaylistId;
  final int? importedTrackCount;
  final String? importedPlaylistName;
  final String? errorMessage;

  const ImportState({
    this.status = ImportStatus.initial,
    this.selectedPlatform,
    this.playlists = const [],
    this.previewTracks = const [],
    this.previewPlaylistId,
    this.importedTrackCount,
    this.importedPlaylistName,
    this.errorMessage,
  });

  ImportState copyWith({
    ImportStatus? status,
    String? selectedPlatform,
    List<ExternalPlaylist>? playlists,
    List<ExternalTrack>? previewTracks,
    String? previewPlaylistId,
    int? importedTrackCount,
    String? importedPlaylistName,
    String? errorMessage,
  }) {
    return ImportState(
      status: status ?? this.status,
      selectedPlatform: selectedPlatform ?? this.selectedPlatform,
      playlists: playlists ?? this.playlists,
      previewTracks: previewTracks ?? this.previewTracks,
      previewPlaylistId: previewPlaylistId ?? this.previewPlaylistId,
      importedTrackCount: importedTrackCount ?? this.importedTrackCount,
      importedPlaylistName: importedPlaylistName ?? this.importedPlaylistName,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status, selectedPlatform, playlists, previewTracks,
        previewPlaylistId, importedTrackCount, importedPlaylistName, errorMessage,
      ];
}

// --- Bloc ---

class ImportBloc extends Bloc<ImportEvent, ImportState> {
  final OAuthService _oauthService;
  final String _userId;

  ImportBloc(this._oauthService, this._userId) : super(const ImportState()) {
    on<ImportLoadPlaylists>(_onLoadPlaylists);
    on<ImportPreviewTracks>(_onPreviewTracks);
    on<ImportExecute>(_onExecute);
    on<ImportClearPreview>(_onClearPreview);
  }

  Future<void> _onLoadPlaylists(ImportLoadPlaylists event, Emitter<ImportState> emit) async {
    emit(state.copyWith(
      status: ImportStatus.loadingPlaylists,
      selectedPlatform: event.platform,
      playlists: [],
      previewTracks: [],
    ));
    try {
      final playlists = await _oauthService.getExternalPlaylists(event.platform, _userId);
      emit(state.copyWith(status: ImportStatus.loaded, playlists: playlists));
    } catch (e) {
      emit(state.copyWith(status: ImportStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onPreviewTracks(ImportPreviewTracks event, Emitter<ImportState> emit) async {
    emit(state.copyWith(
      status: ImportStatus.loadingTracks,
      previewPlaylistId: event.playlistId,
    ));
    try {
      final tracks = await _oauthService.previewTracks(event.platform, event.playlistId, _userId);
      emit(state.copyWith(status: ImportStatus.tracksLoaded, previewTracks: tracks));
    } catch (e) {
      emit(state.copyWith(status: ImportStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onExecute(ImportExecute event, Emitter<ImportState> emit) async {
    emit(state.copyWith(status: ImportStatus.importing));
    try {
      final result = await _oauthService.importPlaylist(
        event.platform,
        event.playlistId,
        _userId,
        playlistName: event.playlistName,
      );
      emit(state.copyWith(
        status: ImportStatus.imported,
        importedTrackCount: result['imported_tracks'] as int?,
        importedPlaylistName: result['playlist_name'] as String?,
      ));
    } catch (e) {
      emit(state.copyWith(status: ImportStatus.error, errorMessage: e.toString()));
    }
  }

  void _onClearPreview(ImportClearPreview event, Emitter<ImportState> emit) {
    emit(state.copyWith(
      status: ImportStatus.loaded,
      previewTracks: [],
      previewPlaylistId: null,
    ));
  }
}
