import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/oauth_service.dart';
import 'connections_event.dart';
import 'connections_state.dart';

class ConnectionsBloc extends Bloc<ConnectionsEvent, ConnectionsState> {
  final OAuthService _oauthService;
  final String _userId;
  StreamSubscription? _pollSubscription;

  ConnectionsBloc(this._oauthService, this._userId) : super(const ConnectionsState()) {
    on<ConnectionsLoad>(_onLoad);
    on<ConnectionsConnect>(_onConnect);
    on<ConnectionsDisconnect>(_onDisconnect);
    on<ConnectionsStopPolling>(_onStopPolling);
    on<ConnectionsUpdated>(_onUpdated);
  }

  Future<void> _onLoad(ConnectionsLoad event, Emitter<ConnectionsState> emit) async {
    emit(state.copyWith(status: ConnectionsStatus.loading));
    try {
      final connections = await _oauthService.getConnections(_userId);
      emit(state.copyWith(status: ConnectionsStatus.loaded, connections: connections));
    } catch (e) {
      emit(state.copyWith(status: ConnectionsStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onConnect(ConnectionsConnect event, Emitter<ConnectionsState> emit) async {
    emit(state.copyWith(
      status: ConnectionsStatus.connecting,
      connectingPlatform: event.platform,
    ));

    try {
      final url = await _oauthService.getConnectUrl(event.platform, _userId);

      // Launch browser
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      emit(state.copyWith(
        status: ConnectionsStatus.connecting,
        connectingPlatform: event.platform,
        authorizeUrl: url,
      ));

      // Start polling for connection
      _pollSubscription?.cancel();
      _pollSubscription = _oauthService.pollConnections(_userId).listen((connections) {
        final isNowConnected = connections.any(
          (c) => c.platform == event.platform && c.connected,
        );
        if (isNowConnected) {
          add(ConnectionsUpdated(
            connections.map((c) => {
              'platform': c.platform,
              'connected': c.connected,
              'display_name': c.displayName,
              'connected_at': c.connectedAt,
            }).toList(),
          ));
        }
      });
    } catch (e) {
      emit(state.copyWith(status: ConnectionsStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onDisconnect(ConnectionsDisconnect event, Emitter<ConnectionsState> emit) async {
    try {
      await _oauthService.disconnect(event.platform, _userId);
      add(const ConnectionsLoad());
    } catch (e) {
      emit(state.copyWith(status: ConnectionsStatus.error, errorMessage: e.toString()));
    }
  }

  void _onStopPolling(ConnectionsStopPolling event, Emitter<ConnectionsState> emit) {
    _pollSubscription?.cancel();
    _pollSubscription = null;
  }

  Future<void> _onUpdated(ConnectionsUpdated event, Emitter<ConnectionsState> emit) async {
    _pollSubscription?.cancel();
    _pollSubscription = null;
    // Reload from server for authoritative state
    add(const ConnectionsLoad());
  }

  @override
  Future<void> close() {
    _pollSubscription?.cancel();
    return super.close();
  }
}
