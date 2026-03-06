import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_client.dart';

// --- Events ---

sealed class CrosslinkEvent extends Equatable {
  const CrosslinkEvent();
  @override
  List<Object?> get props => [];
}

class CrosslinkSubmitted extends CrosslinkEvent {
  final String url;
  const CrosslinkSubmitted(this.url);
  @override
  List<Object?> get props => [url];
}

class CrosslinkCleared extends CrosslinkEvent {
  const CrosslinkCleared();
}

// --- State ---

enum CrosslinkStatus { initial, loading, loaded, error }

class CrosslinkMatch extends Equatable {
  final String platform;
  final String? title;
  final String? artist;
  final String? name;
  final String? url;
  final String? thumbnailUrl;
  final String? imageUrl;
  final bool isPlayable;
  final String? playbackEngine;

  const CrosslinkMatch({
    required this.platform,
    this.title,
    this.artist,
    this.name,
    this.url,
    this.thumbnailUrl,
    this.imageUrl,
    this.isPlayable = false,
    this.playbackEngine,
  });

  factory CrosslinkMatch.fromJson(Map<String, dynamic> json) {
    return CrosslinkMatch(
      platform: json['platform'] as String? ?? '',
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      name: json['name'] as String?,
      url: json['url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      imageUrl: json['image_url'] as String?,
      isPlayable: json['is_playable'] as bool? ?? false,
      playbackEngine: json['playback_engine'] as String?,
    );
  }

  @override
  List<Object?> get props => [platform, url];
}

class CrosslinkState extends Equatable {
  final CrosslinkStatus status;
  final String? type; // 'track' or 'artist'
  final Map<String, dynamic>? original;
  final List<CrosslinkMatch> matches;
  final String? errorMessage;

  const CrosslinkState({
    this.status = CrosslinkStatus.initial,
    this.type,
    this.original,
    this.matches = const [],
    this.errorMessage,
  });

  CrosslinkState copyWith({
    CrosslinkStatus? status,
    String? type,
    Map<String, dynamic>? original,
    List<CrosslinkMatch>? matches,
    String? errorMessage,
  }) {
    return CrosslinkState(
      status: status ?? this.status,
      type: type ?? this.type,
      original: original ?? this.original,
      matches: matches ?? this.matches,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, type, original, matches, errorMessage];
}

// --- Bloc ---

class CrosslinkBloc extends Bloc<CrosslinkEvent, CrosslinkState> {
  final ApiClient _apiClient;

  CrosslinkBloc(this._apiClient) : super(const CrosslinkState()) {
    on<CrosslinkSubmitted>(_onSubmitted);
    on<CrosslinkCleared>(_onCleared);
  }

  Future<void> _onSubmitted(
    CrosslinkSubmitted event,
    Emitter<CrosslinkState> emit,
  ) async {
    emit(const CrosslinkState(status: CrosslinkStatus.loading));

    try {
      final response = await _apiClient.post(
        '/crosslink',
        data: {'url': event.url},
      );

      final data = response.data as Map<String, dynamic>;

      if (data.containsKey('error') && data['matches'] == null) {
        emit(CrosslinkState(
          status: CrosslinkStatus.error,
          errorMessage: data['error'] as String?,
        ));
        return;
      }

      final matches = (data['matches'] as List? ?? [])
          .map((m) => CrosslinkMatch.fromJson(m as Map<String, dynamic>))
          .toList();

      emit(CrosslinkState(
        status: CrosslinkStatus.loaded,
        type: data['type'] as String?,
        original: data['original'] as Map<String, dynamic>?,
        matches: matches,
      ));
    } catch (e) {
      emit(CrosslinkState(
        status: CrosslinkStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onCleared(CrosslinkCleared event, Emitter<CrosslinkState> emit) {
    emit(const CrosslinkState());
  }
}
