import 'package:equatable/equatable.dart';

sealed class ConnectionsEvent extends Equatable {
  const ConnectionsEvent();

  @override
  List<Object?> get props => [];
}

class ConnectionsLoad extends ConnectionsEvent {
  const ConnectionsLoad();
}

class ConnectionsConnect extends ConnectionsEvent {
  final String platform;
  const ConnectionsConnect(this.platform);

  @override
  List<Object?> get props => [platform];
}

class ConnectionsDisconnect extends ConnectionsEvent {
  final String platform;
  const ConnectionsDisconnect(this.platform);

  @override
  List<Object?> get props => [platform];
}

class ConnectionsStopPolling extends ConnectionsEvent {
  const ConnectionsStopPolling();
}

class ConnectionsUpdated extends ConnectionsEvent {
  final List<Map<String, dynamic>> connections;
  const ConnectionsUpdated(this.connections);

  @override
  List<Object?> get props => [connections];
}
