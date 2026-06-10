import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/repository/providers.dart';

class ScreenReader extends ConsumerStatefulWidget {
  const ScreenReader({
    super.key,
    required this.bookId,
    required this.chapterId,
    this.highlightVerseId,
  });

  final int bookId;
  final int chapterId;
  final int? highlightVerseId;

  @override
  ConsumerState<ScreenReader> createState() => _ScreenReaderState();
}

class _ScreenReaderState extends ConsumerState<ScreenReader> {
  double _fontSize = 17;

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));
    final chapterAsync = ref.watch(chapterProvider(widget.chapterId));
    final versesAsync = ref.watch(versesProvider(widget.chapterId));

    return Scaffold(
      appBar: AppBar(
        title: bookAsync.when(
          data: (b) => chapterAsync.when(
            data: (c) => Text('${b?.name ?? ''} ${c?.number ?? ''}'),
            loading: () => const Text('...'),
            error: (_, __) => const Text(''),
          ),
          loading: () => const Text('...'),
          error: (_, __) => const Text(''),
        ),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Tamanho da fonte',
            onSelected: (v) => setState(() => _fontSize = v),
            itemBuilder: (_) => [14.0, 16.0, 17.0, 19.0, 22.0, 26.0]
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Text('${s.toInt()}pt',
                        style: TextStyle(fontSize: s)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (verses) => _VersesList(
          verses: verses,
          fontSize: _fontSize,
          highlightVerseId: widget.highlightVerseId,
          chapterId: widget.chapterId,
          bookId: widget.bookId,
        ),
      ),
      bottomNavigationBar: _ChapterNav(
        bookId: widget.bookId,
        chapterId: widget.chapterId,
      ),
    );
  }
}

class _VersesList extends ConsumerWidget {
  const _VersesList({
    required this.verses,
    required this.fontSize,
    required this.chapterId,
    required this.bookId,
    this.highlightVerseId,
  });

  final List<Verse> verses;
  final double fontSize;
  final int? highlightVerseId;
  final int chapterId;
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: verses.length,
      itemBuilder: (context, i) {
        final verse = verses[i];
        final isHighlighted = verse.id == highlightVerseId;
        return _VerseItem(
          verse: verse,
          fontSize: fontSize,
          isHighlighted: isHighlighted,
        );
      },
    );
  }
}

class _VerseItem extends ConsumerStatefulWidget {
  const _VerseItem({
    required this.verse,
    required this.fontSize,
    required this.isHighlighted,
  });
  final Verse verse;
  final double fontSize;
  final bool isHighlighted;

  @override
  ConsumerState<_VerseItem> createState() => _VerseItemState();
}

class _VerseItemState extends ConsumerState<_VerseItem> {
  @override
  Widget build(BuildContext context) {
    final bookmarkedAsync = ref.watch(isBookmarkedProvider(widget.verse.id));
    final isBookmarked = bookmarkedAsync.valueOrNull ?? false;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: () => _showVerseOptions(context, isBookmarked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isHighlighted
              ? scheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isBookmarked
              ? Border.all(color: scheme.secondary, width: 1.5)
              : null,
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: widget.fontSize,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              height: 1.7,
            ),
            children: [
              TextSpan(
                text: '${widget.verse.number} ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: widget.fontSize * 0.75,
                  color: scheme.primary,
                  fontFeatures: const [],
                ),
              ),
              TextSpan(text: widget.verse.verseText),
            ],
          ),
        ),
      ),
    );
  }

  void _showVerseOptions(BuildContext context, bool isBookmarked) {
    final repo = ref.read(bibleRepositoryProvider);
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add),
              title: Text(isBookmarked
                  ? 'Remover favorito'
                  : 'Adicionar aos favoritos'),
              onTap: () async {
                Navigator.pop(context);
                if (isBookmarked) {
                  final bookmarks = ref.read(bookmarksProvider).valueOrNull;
                  final bm = bookmarks
                      ?.where((b) => b.verse.id == widget.verse.id)
                      .firstOrNull;
                  if (bm != null) {
                    await repo.removeBookmark(bm.bookmark.id);
                  }
                } else {
                  await repo.addBookmark(widget.verse.id);
                }
                ref.invalidate(isBookmarkedProvider(widget.verse.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterNav extends ConsumerWidget {
  const _ChapterNav({required this.bookId, required this.chapterId});
  final int bookId;
  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(bookId));
    return chaptersAsync.when(
      data: (chapters) {
        final ids = chapters.map((c) => c.id).toList();
        final idx = ids.indexOf(chapterId);
        final hasPrev = idx > 0;
        final hasNext = idx < ids.length - 1;
        return BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: hasPrev
                    ? () => context.pushReplacement(
                          '/books/$bookId/chapters/${ids[idx - 1]}',
                        )
                    : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Anterior'),
              ),
              TextButton.icon(
                onPressed: hasNext
                    ? () => context.pushReplacement(
                          '/books/$bookId/chapters/${ids[idx + 1]}',
                        )
                    : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Próximo'),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
