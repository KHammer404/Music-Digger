import 'package:equatable/equatable.dart';

import '../../../core/services/oauth_service.dart';

enum ConnectionsStatus { initial, loading, loaded, connecting, error }

class ConnectionsState extends Equatable {
  final ConnectionsStatus status;
  final List<OAuthConnection> connections;
  final String? connectingPlatform;
  final String? authorizeUrl;
  final String? errorMessage;

  const ConnectionsState({
    this.status = ConnectionsStatus.initial,
    this.connections = const [],
    this.connectingPlatform,
    this.authorizeUrl,
    this.errorMessage,
  });

  bool isConnected(String platform) {
    return connections.any((c) => c.platform == platform && c.connected);
  }

  OAuthConnection? getConnection(String platform) {
    try {
      return connections.firstWhere((c) => c.platform == platform);
    } catch (_) {
      return null;
    }
  }

  ConnectionsState copyWith({
    ConnectionsStatus? status,
    List<OAuthConnection>? connections,
    String? connectingPlatform,
    String? authorizeUrl,
    String? errorMessage,
  }) {
    return ConnectionsState(
      status: status ?? this.status,
      connections: connections ?? this.connections,
      connectingPlatform: connectingPlatform,
      authorizeUrl: authorizeUrl,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, connections, connectingPlatform, authorizeUrl, errorMessage];
}
