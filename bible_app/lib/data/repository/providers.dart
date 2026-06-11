import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import 'bible_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Initialize via ProviderScope override');
});

final bibleRepositoryProvider = Provider<BibleRepository>((ref) {
  return BibleRepository(ref.watch(appDatabaseProvider));
});

// ── Books ──────────────────────────────────────────────────────────────────────

final booksProvider = FutureProvider<List<Book>>((ref) {
  return ref.watch(bibleRepositoryProvider).getBooks();
});

// ── Chapters ───────────────────────────────────────────────────────────────────

final chaptersProvider =
    FutureProvider.family<List<Chapter>, int>((ref, bookId) {
  return ref.watch(bibleRepositoryProvider).getChapters(bookId);
});

// ── Verses ─────────────────────────────────────────────────────────────────────

final versesProvider =
    FutureProvider.family<List<Verse>, int>((ref, chapterId) {
  return ref.watch(bibleRepositoryProvider).getVerses(chapterId);
});

// ── Single items ───────────────────────────────────────────────────────────────

final bookProvider = FutureProvider.family<Book?, int>((ref, id) {
  return ref.watch(bibleRepositoryProvider).getBook(id);
});

final chapterProvider = FutureProvider.family<Chapter?, int>((ref, id) {
  return ref.watch(bibleRepositoryProvider).getChapter(id);
});

// ── Bookmarks ──────────────────────────────────────────────────────────────────

final bookmarksProvider =
    StreamProvider<List<BookmarkWithVerse>>((ref) {
  return ref.watch(bibleRepositoryProvider).watchBookmarks();
});

final isBookmarkedProvider = FutureProvider.family<bool, int>((ref, verseId) {
  return ref.watch(bibleRepositoryProvider).isBookmarked(verseId);
});

// ── Highlights ─────────────────────────────────────────────────────────────────

final highlightsDaoProvider = Provider<HighlightsDao>((ref) {
  return ref.watch(appDatabaseProvider).highlightsDao;
});

final verseHighlightProvider =
    FutureProvider.family<int?, int>((ref, verseId) async {
  final dao = ref.watch(highlightsDaoProvider);
  final result = await dao.getHighlight(verseId);
  return result?.highlight.colorIndex;
});

final highlightsWithDetailsProvider =
    StreamProvider<List<HighlightWithDetails>>((ref) {
  final dao = ref.watch(highlightsDaoProvider);
  final repo = ref.watch(bibleRepositoryProvider);

  return dao.watchHighlights().asyncMap((items) async {
    final result = <HighlightWithDetails>[];
    for (final h in items) {
      final book = await repo.getBook(h.verse.bookId);
      final chapter = await repo.getChapter(h.verse.chapterId);
      if (book != null && chapter != null) {
        result.add(HighlightWithDetails(
          highlight: h.highlight,
          verse: h.verse,
          book: book,
          chapter: chapter,
        ));
      }
    }
    return result;
  });
});
