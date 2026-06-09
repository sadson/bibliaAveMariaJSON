import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/books/screen_books.dart';
import 'features/bookmarks/screen_bookmarks.dart';
import 'features/chapters/screen_chapters.dart';
import 'features/reader/screen_reader.dart';
import 'features/search/screen_search.dart';

final _router = GoRouter(
  routes: [
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
  ],
);

class BibleApp extends StatelessWidget {
  const BibleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bíblia Ave Maria',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
