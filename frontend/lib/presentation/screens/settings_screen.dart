import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/service_locator.dart';
import '../../core/services/oauth_service.dart';
import '../../core/services/user_service.dart';
import '../blocs/connections/connections_bloc.dart';
import '../blocs/connections/connections_event.dart';
import '../blocs/connections/connections_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _offlineMode = false;
  String _audioQuality = 'High';
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const _SettingsSection(title: 'General'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Dark'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          const _SettingsSection(title: 'Playback'),
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: const Text('Audio Quality'),
            subtitle: Text(_audioQuality),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityDialog(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_off),
            title: const Text('Offline Mode'),
            subtitle: const Text('Cache tracks for offline playback'),
            value: _offlineMode,
            onChanged: (value) {
              setState(() => _offlineMode = value);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(value ? 'Offline mode enabled' : 'Offline mode disabled'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const Divider(),
          const _SettingsSection(title: 'Platform Accounts'),
          BlocProvider(
            create: (_) {
              final bloc = ConnectionsBloc(
                getIt<OAuthService>(),
                getIt<UserService>().userId,
              );
              bloc.add(const ConnectionsLoad());
              return bloc;
            },
            child: BlocBuilder<ConnectionsBloc, ConnectionsState>(
              builder: (context, state) {
                return Column(
                  children: [
                    _platformTile(context, state, 'spotify', 'Spotify', Icons.music_note, const Color(0xFF1DB954)),
                    _platformTile(context, state, 'youtube', 'YouTube', Icons.play_circle_fill, const Color(0xFFFF0000)),
                    _platformTile(context, state, 'tidal', 'Tidal', Icons.waves, Colors.white70),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          const _SettingsSection(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.cached),
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove cached search results and images'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Cache?'),
                  content: const Text('This will remove all cached data. Your playlists and favorites will not be affected.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache cleared')),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const _SettingsSection(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('0.1.0-beta'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licenses'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Music Digger',
                applicationVersion: '0.1.0-beta',
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language'),
        children: [
          _langOption(ctx, 'English'),
          _langOption(ctx, '한국어'),
          _langOption(ctx, '日本語'),
        ],
      ),
    );
  }

  Widget _langOption(BuildContext ctx, String lang) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => _language = lang);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          if (_language == lang)
            const Icon(Icons.check, size: 20, color: Color(0xFF6C5CE7))
          else
            const SizedBox(width: 20),
          const SizedBox(width: 12),
          Text(lang),
        ],
      ),
    );
  }

  void _showQualityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Audio Quality'),
        children: [
          _qualityOption(ctx, 'Low', '64 kbps - saves data'),
          _qualityOption(ctx, 'Medium', '128 kbps - balanced'),
          _qualityOption(ctx, 'High', '256 kbps - best quality'),
        ],
      ),
    );
  }

  Widget _platformTile(BuildContext context, ConnectionsState state, String platform, String name, IconData icon, Color color) {
    final connected = state.isConnected(platform);
    final conn = state.getConnection(platform);
    final isConnecting = state.status == ConnectionsStatus.connecting && state.connectingPlatform == platform;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(name),
      subtitle: Text(
        isConnecting
            ? 'Connecting...'
            : connected
                ? 'Connected as ${conn?.displayName ?? name}'
                : 'Not connected',
      ),
      trailing: isConnecting
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : connected
              ? TextButton(
                  onPressed: () {
                    context.read<ConnectionsBloc>().add(ConnectionsDisconnect(platform));
                  },
                  child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                )
              : TextButton(
                  onPressed: () {
                    context.read<ConnectionsBloc>().add(ConnectionsConnect(platform));
                  },
                  child: const Text('Connect'),
                ),
    );
  }

  Widget _qualityOption(BuildContext ctx, String quality, String desc) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => _audioQuality = quality);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          if (_audioQuality == quality)
            const Icon(Icons.check, size: 20, color: Color(0xFF6C5CE7))
          else
            const SizedBox(width: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quality),
                Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;

  const _SettingsSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
