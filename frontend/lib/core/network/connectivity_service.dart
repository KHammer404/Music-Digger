import 'dart:async';
import 'dart:io';

/// Lightweight connectivity checker — no extra packages needed.
/// Tries to resolve a DNS lookup to check internet availability.
class ConnectivityService {
  ConnectivityService._();
  static final instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Timer? _timer;

  void startMonitoring() {
    // Check immediately
    checkNow();
    // Then check every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => checkNow());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> checkNow() async {
    try {
      final result = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 3));
      _setOnline(result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } on SocketException {
      _setOnline(false);
    } on TimeoutException {
      _setOnline(false);
    } catch (_) {
      _setOnline(false);
    }
    return _isOnline;
  }

  void _setOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      _controller.add(value);
    }
  }

  void dispose() {
    stopMonitoring();
    _controller.close();
  }
}
