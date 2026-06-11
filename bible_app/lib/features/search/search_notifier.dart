import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repository/bible_repository.dart';
import '../../data/repository/providers.dart';
import '../../services/embedding_service.dart';
import '../../services/prefs_service.dart';
import 'bible_ref_parser.dart';

enum SearchMode { text, semantic }

enum TestamentFilter { all, at, nt }

// ── Result types ──────────────────────────────────────────────────────────────

class SearchResult {
  const SearchResult({
    required this.verse,
    required this.book,
    required this.chapter,
    this.score,
  });
  final Verse verse;
  final Book book;
  final Chapter chapter;
  final double? score;
}

class RefResult {
  const RefResult({required this.book, required this.chapter, this.verse});
  final Book book;
  final Chapter chapter;
  final Verse? verse;

  String get label {
    final ch = chapter.number;
    return verse != null
        ? '${book.name} $ch:${verse!.number}'
        : '${book.name} $ch';
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class SearchState {
  const SearchState({
    this.mode = SearchMode.semantic,
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.embeddingServiceReady = false,
    this.embeddingLoadError,
    this.refResult,
    this.searchHistory = const [],
    this.testamentFilter = TestamentFilter.all,
  });

  final SearchMode mode;
  final String query;
  final List<SearchResult> results;
  final bool isLoading;
  final String? error;
  final bool embeddingServiceReady;
  final String? embeddingLoadError;
  final RefResult? refResult;
  final List<String> searchHistory;
  final TestamentFilter testamentFilter;

  SearchState copyWith({
    SearchMode? mode,
    String? query,
    List<SearchResult>? results,
    bool? isLoading,
    String? error,
    bool? embeddingServiceReady,
    String? embeddingLoadError,
    RefResult? refResult,
    bool clearRefResult = false,
    List<String>? searchHistory,
    TestamentFilter? testamentFilter,
  }) =>
      SearchState(
        mode: mode ?? this.mode,
        query: query ?? this.query,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        embeddingServiceReady:
            embeddingServiceReady ?? this.embeddingServiceReady,
        embeddingLoadError: embeddingLoadError ?? this.embeddingLoadError,
        refResult: clearRefResult ? null : (refResult ?? this.refResult),
        searchHistory: searchHistory ?? this.searchHistory,
        testamentFilter: testamentFilter ?? this.testamentFilter,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SearchNotifier extends AutoDisposeNotifier<SearchState> {
  late BibleRepository _repo;
  EmbeddingService? _embeddings;

  @override
  SearchState build() {
    _repo = ref.watch(bibleRepositoryProvider);
    _initEmbeddings();
    final history = _loadHistorySync();
    return SearchState(searchHistory: history);
  }

  List<String> _loadHistorySync() {
    try {
      return PrefsService.instance.getSearchHistory();
    } catch (_) {
      return const [];
    }
  }

  void _initEmbeddings() async {
    try {
      _embeddings = await EmbeddingService.load();
      state = state.copyWith(embeddingServiceReady: true);
    } catch (e, st) {
      state = state.copyWith(embeddingLoadError: '$e\n$st');
    }
  }

  void setTestamentFilter(TestamentFilter filter) {
    state = state.copyWith(testamentFilter: filter);
  }

  Future<void> clearHistory() async {
    try {
      await PrefsService.instance.clearSearchHistory();
      state = state.copyWith(searchHistory: []);
    } catch (_) {}
  }

  // Chamado quando o usuário navega para um versículo — registra apenas
  // a query que estava ativa nesse momento, não cada keystroke intermediário.
  Future<void> recordSearch() async {
    final q = state.query;
    if (q.isEmpty) return;
    try {
      await PrefsService.instance.saveSearchQuery(q);
      state = state.copyWith(
        searchHistory: PrefsService.instance.getSearchHistory(),
      );
    } catch (_) {}
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = state.copyWith(
        query: '',
        results: [],
        isLoading: false,
        clearRefResult: true,
      );
      return;
    }

    state = state.copyWith(
      query: q,
      isLoading: true,
      error: null,
      clearRefResult: true,
    );

    try {
      final both = await Future.wait([
        _tryParseRef(q),
        _runSearch(q),
      ]);
      final ref = both[0] as RefResult?;
      final results = both[1] as List<SearchResult>;

      state = state.copyWith(
        results: results,
        isLoading: false,
        refResult: ref,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        clearRefResult: true,
      );
    }
  }

  // ── Reference resolution ─────────────────────────────────────────────────

  Future<RefResult?> _tryParseRef(String query) async {
    final parsed = BibleRefParser.parse(query);
    if (parsed == null) return null;
    final book = await _repo.getBook(parsed.bookId);
    if (book == null) return null;
    final chapter = await _repo.findChapter(parsed.bookId, parsed.chapter);
    if (chapter == null) return null;
    Verse? verse;
    if (parsed.verse != null) {
      verse = await _repo.findVerse(chapter.id, parsed.verse!);
    }
    return RefResult(book: book, chapter: chapter, verse: verse);
  }

  // ── Search dispatch ───────────────────────────────────────────────────────

  // Uses semantic when embeddings are ready; silently falls back to text.
  Future<List<SearchResult>> _runSearch(String query) {
    if (_embeddings != null) return _semanticSearch(query);
    return _textSearch(query);
  }

  // ── Text / semantic search ────────────────────────────────────────────────

  Future<List<SearchResult>> _textSearch(String query) async {
    final verses = await _repo.searchText(query);
    final enriched = await _enrichVerses(verses);
    return _applyFilter(enriched);
  }

  Future<List<SearchResult>> _semanticSearch(String query) async {
    if (_embeddings == null) throw Exception('Busca semântica não disponível');
    final hits = await _embeddings!.search(query);
    final idOrder = {for (final h in hits) h.verseId: h.score};
    final verses = await _repo.getVersesByIds(hits.map((h) => h.verseId).toList());
    verses.sort((a, b) =>
        (idOrder[b.id] ?? 0).compareTo(idOrder[a.id] ?? 0));
    final enriched = await _enrichVerses(verses);
    return _applyFilter(enriched)
        .map((r) => SearchResult(
              verse: r.verse,
              book: r.book,
              chapter: r.chapter,
              score: idOrder[r.verse.id],
            ))
        .toList();
  }

  Future<List<SearchResult>> _enrichVerses(List<Verse> verses) async {
    final results = <SearchResult>[];
    for (final v in verses) {
      final book = await _repo.getBook(v.bookId);
      final chapter = await _repo.getChapter(v.chapterId);
      if (book != null && chapter != null) {
        results.add(SearchResult(verse: v, book: book, chapter: chapter));
      }
    }
    return results;
  }

  List<SearchResult> _applyFilter(List<SearchResult> results) {
    if (state.testamentFilter == TestamentFilter.all) return results;
    final t = state.testamentFilter == TestamentFilter.at ? 'AT' : 'NT';
    return results.where((r) => r.book.testament == t).toList();
  }
}

final searchNotifierProvider =
    AutoDisposeNotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
