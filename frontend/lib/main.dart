import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'core/di/service_locator.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'core/services/user_service.dart';
import 'l10n/app_localizations.dart';
import 'playback/playback_manager.dart';
import 'presentation/blocs/player/player_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  setupServiceLocator();
  await getIt<UserService>().initialize();
  ConnectivityService.instance.startMonitoring();
  runApp(const MusicDiggerApp());
}

class MusicDiggerApp extends StatelessWidget {
  const MusicDiggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayerBloc(PlaybackManager(), getIt<ApiClient>()),
      child: MaterialApp.router(
        title: 'Music Digger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
          Locale('ja'),
        ],
      ),
    );
  }
}
