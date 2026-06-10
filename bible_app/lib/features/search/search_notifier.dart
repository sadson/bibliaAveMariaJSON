import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repository/bible_repository.dart';
import '../../data/repository/providers.dart';
import '../../services/embedding_service.dart';

enum SearchMode { text, semantic }

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

class SearchState {
  const SearchState({
    this.mode = SearchMode.text,
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.embeddingServiceReady = false,
  });

  final SearchMode mode;
  final String query;
  final List<SearchResult> results;
  final bool isLoading;
  final String? error;
  final bool embeddingServiceReady;

  SearchState copyWith({
    SearchMode? mode,
    String? query,
    List<SearchResult>? results,
    bool? isLoading,
    String? error,
    bool? embeddingServiceReady,
  }) =>
      SearchState(
        mode: mode ?? this.mode,
        query: query ?? this.query,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        embeddingServiceReady:
            embeddingServiceReady ?? this.embeddingServiceReady,
      );
}

class SearchNotifier extends AutoDisposeNotifier<SearchState> {
  late BibleRepository _repo;
  EmbeddingService? _embeddings;

  @override
  SearchState build() {
    _repo = ref.watch(bibleRepositoryProvider);
    _initEmbeddings();
    return const SearchState();
  }

  void _initEmbeddings() async {
    try {
      _embeddings = await EmbeddingService.load();
      state = state.copyWith(embeddingServiceReady: true);
    } catch (e) {
      // Semantic search unavailable if model not found
    }
  }

  void setMode(SearchMode mode) {
    state = state.copyWith(mode: mode, results: [], query: '');
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = state.copyWith(query: '', results: [], isLoading: false);
      return;
    }
    state = state.copyWith(query: q, isLoading: true, error: null);
    try {
      final results = state.mode == SearchMode.text
          ? await _textSearch(q)
          : await _semanticSearch(q);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<SearchResult>> _textSearch(String query) async {
    final verses = await _repo.searchText(query);
    return _enrichVerses(verses);
  }

  Future<List<SearchResult>> _semanticSearch(String query) async {
    if (_embeddings == null) throw Exception('Busca semântica não disponível');
    final hits = await _embeddings!.search(query);
    final ids = hits.map((h) => h.verseId).toList();
    final verses = await _repo.getVersesByIds(ids);
    // Preserve ranking order from semantic search
    final idOrder = {for (final h in hits) h.verseId: h.score};
    verses.sort((a, b) =>
        (idOrder[b.id] ?? 0).compareTo(idOrder[a.id] ?? 0));
    final results = await _enrichVerses(verses);
    for (int i = 0; i < results.length; i++) {
      // Re-attach scores — create new SearchResult with score
    }
    return results;
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
}

final searchNotifierProvider =
    AutoDisposeNotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
