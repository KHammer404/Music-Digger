import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/artist_detail_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/search_screen.dart';
import '../presentation/screens/library_screen.dart';
import '../presentation/screens/player_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Full-screen routes (outside shell) with slide-up transition
    GoRoute(
      path: '/artist/:artistId',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        final artistId = state.pathParameters['artistId']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ArtistDetailScreen(artistId: artistId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/player',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const PlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        );
      },
    ),
  ],
);
