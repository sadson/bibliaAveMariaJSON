import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/books/screen_books.dart';
import 'features/bookmarks/screen_bookmarks.dart';
import 'features/chapters/screen_chapters.dart';
import 'features/reader/screen_reader.dart';
import 'features/search/screen_search.dart';
import 'features/highlights/screen_highlights.dart';
import 'features/settings/screen_settings.dart';
import 'features/settings/settings_notifier.dart';
import 'features/splash/screen_splash.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (_, __) => const ScreenSplash(),
    ),
    GoRoute(
      path: '/',
      builder: (_, __) => const ScreenBooks(),
    ),
    GoRoute(
      path: '/books/:bookId/chapters',
      builder: (_, state) => ScreenChapters(
        bookId: int.parse(state.pathParameters['bookId']!),
      ),
    ),
    GoRoute(
      path: '/books/:bookId/chapters/:chapterId',
      builder: (_, state) => ScreenReader(
        bookId: int.parse(state.pathParameters['bookId']!),
        chapterId: int.parse(state.pathParameters['chapterId']!),
        highlightVerseId: state.extra as int?,
      ),
    ),
    GoRoute(
      path: '/search',
      builder: (_, __) => const ScreenSearch(),
    ),
    GoRoute(
      path: '/bookmarks',
      builder: (_, __) => const ScreenBookmarks(),
    ),
    GoRoute(
      path: '/highlights',
      builder: (_, __) => const ScreenHighlights(),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const ScreenSettings(),
    ),
  ],
);

class BibleApp extends ConsumerWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Bíblia Ave Maria',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
