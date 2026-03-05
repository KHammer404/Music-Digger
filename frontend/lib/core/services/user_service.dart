import 'dart:developer' as dev;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';

class UserService {
  static const _keyDeviceId = 'device_id';
  static const _keyUserId = 'user_id';

  final ApiClient _api;

  String _deviceId = '';
  String _userId = '';

  String get deviceId => _deviceId;
  String get userId => _userId;

  UserService(this._api);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_keyDeviceId) ?? '';
    _userId = prefs.getString(_keyUserId) ?? '';

    // Generate device_id on first launch
    if (_deviceId.isEmpty) {
      _deviceId = const Uuid().v4();
      await prefs.setString(_keyDeviceId, _deviceId);
      dev.log('[UserService] New device_id: $_deviceId', name: 'UserService');
    }

    // Register with backend if we don't have a user_id yet
    if (_userId.isEmpty) {
      await _register(prefs);
    }

    dev.log('[UserService] Ready — userId=$_userId', name: 'UserService');
  }

  Future<void> _register(SharedPreferences prefs) async {
    try {
      final response = await _api.post(
        '/users/register',
        data: {'device_id': _deviceId},
      );
      final id = response.data['id'] as String?;
      if (id != null && id.isNotEmpty) {
        _userId = id;
        await prefs.setString(_keyUserId, _userId);
        dev.log('[UserService] Registered user: $_userId', name: 'UserService');
      }
    } catch (e) {
      // Offline or server down — generate a local UUID as fallback.
      // Will retry registration next launch.
      _userId = const Uuid().v4();
      dev.log('[UserService] Registration failed, using local id: $_userId ($e)',
          name: 'UserService');
    }
  }
}
