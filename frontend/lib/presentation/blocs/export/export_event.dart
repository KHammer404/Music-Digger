import 'package:equatable/equatable.dart';

sealed class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => [];
}

class ExportPlaylist extends ExportEvent {
  final String playlistId;
  final String playlistName;
  final ExportFormat format;

  const ExportPlaylist({
    required this.playlistId,
    required this.playlistName,
    required this.format,
  });

  @override
  List<Object?> get props => [playlistId, format];
}

class ImportPlaylistFromJson extends ExportEvent {
  final String name;
  final String userId;
  final List<Map<String, dynamic>> tracks;

  const ImportPlaylistFromJson({
    required this.name,
    required this.userId,
    required this.tracks,
  });

  @override
  List<Object?> get props => [name, userId, tracks];
}

class ExportClearStatus extends ExportEvent {
  const ExportClearStatus();
}

enum ExportFormat { json, csv, m3u }
