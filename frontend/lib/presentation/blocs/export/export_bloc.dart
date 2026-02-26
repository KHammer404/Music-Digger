import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';
import 'export_event.dart';
import 'export_state.dart';

class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final ApiClient _apiClient;

  ExportBloc(this._apiClient) : super(const ExportState()) {
    on<ExportPlaylist>(_onExport);
    on<ImportPlaylistFromJson>(_onImport);
    on<ExportClearStatus>(_onClear);
  }

  Future<void> _onExport(ExportPlaylist event, Emitter<ExportState> emit) async {
    emit(state.copyWith(status: ExportStatus.exporting));
    try {
      final formatStr = switch (event.format) {
        ExportFormat.json => 'json',
        ExportFormat.csv => 'csv',
        ExportFormat.m3u => 'm3u',
      };

      await _apiClient.get('/export/playlists/${event.playlistId}/$formatStr');

      emit(state.copyWith(
        status: ExportStatus.exported,
        message: '${event.playlistName} exported as ${formatStr.toUpperCase()}',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExportStatus.error,
        errorMessage: 'Export failed: ${e.toString()}',
      ));
    }
  }

  Future<void> _onImport(ImportPlaylistFromJson event, Emitter<ExportState> emit) async {
    emit(state.copyWith(status: ExportStatus.importing));
    try {
      final resp = await _apiClient.post('/export/playlists/import/json', data: {
        'name': event.name,
        'user_id': event.userId,
        'tracks': event.tracks,
      });

      final data = resp.data as Map<String, dynamic>;
      final imported = data['imported_tracks'] as int;

      emit(state.copyWith(
        status: ExportStatus.imported,
        message: 'Imported $imported tracks to "${event.name}"',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExportStatus.error,
        errorMessage: 'Import failed: ${e.toString()}',
      ));
    }
  }

  void _onClear(ExportClearStatus event, Emitter<ExportState> emit) {
    emit(const ExportState());
  }
}
