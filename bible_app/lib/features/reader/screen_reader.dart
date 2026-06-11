import 'dart:math' show max;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/database.dart';
import '../../data/repository/providers.dart';
import '../../services/prefs_service.dart';

// ---------------------------------------------------------------------------
// ScreenReader
// ---------------------------------------------------------------------------

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
  late double _fontSize;

  /// Lazily initialised once chapters are available.
  PageController? _pageCtrl;

  /// Index of the page currently visible.
  int _currentPageIndex = 0;

  /// Id of the chapter currently on screen (drives the AppBar title).
  int _currentChapterId = 0;

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.chapterId;
    _fontSize = PrefsService.instance.getFontSize();
  }

  @override
  void dispose() {
    _pageCtrl?.dispose();
    super.dispose();
  }

  /// Creates (once) the [PageController] positioned at the correct chapter.
  PageController _initPageController(List<Chapter> chapters) {
    if (_pageCtrl != null) return _pageCtrl!;

    final idx = chapters.indexWhere((c) => c.id == widget.chapterId);
    _currentPageIndex = idx < 0 ? 0 : idx;
    _pageCtrl = PageController(initialPage: _currentPageIndex);
    return _pageCtrl!;
  }

  // ── Chapter picker ──────────────────────────────────────────────────────────

  void _showChapterPicker(BuildContext context, List<Chapter> chapters) {
    final count = chapters.length;
    final initialSize = count <= 6 ? 0.25 : count <= 18 ? 0.40 : 0.55;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: 0.2,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ir para capítulo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: chapters.length,
                itemBuilder: (_, idx) => _ChapterCell(
                  number: chapters[idx].number,
                  isCurrent: idx == _currentPageIndex,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _pageCtrl?.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveLastRead(List<Chapter> chapters, Book? book) {
    if (book == null || chapters.isEmpty) return;
    final chapter = chapters[_currentPageIndex];
    PrefsService.instance.saveLastRead(
      widget.bookId,
      chapter.id,
      chapter.number,
      book.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookProvider(widget.bookId));
    final chaptersAsync = ref.watch(chaptersProvider(widget.bookId));
    final currentChapterAsync = ref.watch(chapterProvider(_currentChapterId));

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => chaptersAsync.whenData((chapters) {
            if (chapters.isNotEmpty) _showChapterPicker(context, chapters);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: bookAsync.when(
              data: (book) => currentChapterAsync.when(
                data: (ch) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${book?.name ?? ''} ${ch?.number ?? ''}'),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
                loading: () => const Text('...'),
                error: (_, __) => const Text(''),
              ),
              loading: () => const Text('...'),
              error: (_, __) => const Text(''),
            ),
          ),
        ),
        actions: [
          // Chapter counter.
          chaptersAsync.maybeWhen(
            data: (chapters) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  '${_currentPageIndex + 1} / ${chapters.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          // Font size picker.
          PopupMenuButton<double>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Tamanho da fonte',
            onSelected: (v) {
              setState(() => _fontSize = v);
              PrefsService.instance.saveFontSize(v);
            },
            itemBuilder: (_) => [14.0, 16.0, 17.0, 19.0, 22.0, 26.0]
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Text(
                      '${s.toInt()}pt',
                      style: TextStyle(fontSize: s),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (chapters) {
          if (chapters.isEmpty) {
            return const Center(child: Text('Nenhum capítulo encontrado.'));
          }

          final ctrl = _initPageController(chapters);

          // Persist last-read position on first render.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bookAsync.whenData((book) => _saveLastRead(chapters, book));
          });

          return PageView.builder(
            controller: ctrl,
            itemCount: chapters.length,
            onPageChanged: (idx) {
              setState(() {
                _currentPageIndex = idx;
                _currentChapterId = chapters[idx].id;
              });
              bookAsync.whenData((book) => _saveLastRead(chapters, book));
            },
            itemBuilder: (context, idx) {
              final chapter = chapters[idx];
              final versesAsync = ref.watch(versesProvider(chapter.id));
              final isInitialPage = chapter.id == widget.chapterId;

              return versesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (verses) => _VersesList(
                  verses: verses,
                  fontSize: _fontSize,
                  highlightVerseId:
                      isInitialPage ? widget.highlightVerseId : null,
                  chapterId: chapter.id,
                  bookId: widget.bookId,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _VersesList
// ---------------------------------------------------------------------------

class _VersesList extends ConsumerStatefulWidget {
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
  ConsumerState<_VersesList> createState() => _VersesListState();
}

class _VersesListState extends ConsumerState<_VersesList> {
  late final ScrollController _scrollCtrl;
  final _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();

    if (widget.highlightVerseId != null) {
      final idx =
          widget.verses.indexWhere((v) => v.id == widget.highlightVerseId);
      if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToVerse(idx));
      }
    }
  }

  // Dois passos: jumpTo aproximado para trazer o item à árvore, depois
  // ensureVisible para posicionamento exato. Necessário porque ListView.builder
  // é lazy — o item pode não ter sido renderizado ainda se estiver longe do topo.
  void _scrollToVerse(int idx) {
    if (!mounted) return;
    final ctx = _highlightKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
      return;
    }
    if (!_scrollCtrl.hasClients) return;
    // Pula para posição estimada (90 px/verso é mais conservador que 72)
    _scrollCtrl.jumpTo(max(0.0, (idx - 2) * 90.0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx2 = _highlightKey.currentContext;
      if (ctx2 != null) {
        Scrollable.ensureVisible(
          ctx2,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: widget.verses.length,
      itemBuilder: (context, i) {
        final verse = widget.verses[i];
        final isSearchHighlighted = verse.id == widget.highlightVerseId;
        return _VerseItem(
          key: isSearchHighlighted ? _highlightKey : ValueKey(verse.id),
          verse: verse,
          fontSize: widget.fontSize,
          isSearchHighlighted: isSearchHighlighted,
          bookId: widget.bookId,
          chapterId: widget.chapterId,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _VerseItem
// ---------------------------------------------------------------------------

class _VerseItem extends ConsumerStatefulWidget {
  const _VerseItem({
    super.key,
    required this.verse,
    required this.fontSize,
    required this.isSearchHighlighted,
    required this.bookId,
    required this.chapterId,
  });

  final Verse verse;
  final double fontSize;

  /// True when this verse was navigated to from the search screen.
  final bool isSearchHighlighted;
  final int bookId;
  final int chapterId;

  @override
  ConsumerState<_VerseItem> createState() => _VerseItemState();
}

class _VerseItemState extends ConsumerState<_VerseItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _glowCtrl;
  Animation<double>? _glow;
  bool _glowDone = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSearchHighlighted) return;

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _glow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 16),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
    ]).animate(_glowCtrl!);

    // Quando o glow termina, troca para o container estático com a cor real
    // do destaque (caso o versículo tenha um highlight salvo no banco).
    _glowCtrl!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _glowDone = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _glowCtrl!.forward();
    });
  }

  @override
  void dispose() {
    _glowCtrl?.dispose();
    super.dispose();
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookmarkedAsync = ref.watch(isBookmarkedProvider(widget.verse.id));
    final isBookmarked = bookmarkedAsync.valueOrNull ?? false;

    final highlightAsync = ref.watch(verseHighlightProvider(widget.verse.id));
    final highlightColorIndex = highlightAsync.valueOrNull;

    // Derive note state from the bookmarks stream.
    final bookmarksAsync = ref.watch(bookmarksProvider);
    final BookmarkWithVerse? bookmarkEntry = bookmarksAsync.valueOrNull
        ?.where((b) => b.verse.id == widget.verse.id)
        .firstOrNull;
    final hasNote =
        bookmarkEntry != null &&
        (bookmarkEntry.bookmark.note?.isNotEmpty ?? false);

    final scheme = Theme.of(context).colorScheme;
    final textContent = _buildVerseText(context, scheme, hasNote);

    return GestureDetector(
      onLongPress: () => _showVerseOptions(
        context,
        isBookmarked: isBookmarked,
        highlightColorIndex: highlightColorIndex,
        currentNote: bookmarkEntry?.bookmark.note,
        bookmarkId: bookmarkEntry?.bookmark.id,
      ),
      child: widget.isSearchHighlighted && _glowCtrl != null && !_glowDone
          // Glow animation: ativo só até a animação terminar.
          // Após _glowDone=true, cai no branch estático e mostra a cor
          // real do destaque (se o versículo tiver um highlight salvo).
          ? AnimatedBuilder(
              animation: _glowCtrl!,
              builder: (_, child) {
                final g = _glow!.value;
                return _buildContainer(
                  color: scheme.primary.withValues(alpha: 0.11 * g),
                  shadow1Color: scheme.primary.withValues(alpha: 0.55 * g),
                  shadow1Blur: 12 * g,
                  shadow2Color: scheme.primary.withValues(alpha: 0.25 * g),
                  shadow2Blur: 28 * g,
                  shadow2Spread: 5 * g,
                  isBookmarked: isBookmarked,
                  borderColor: scheme.secondary,
                  showShadow: g > 0.01,
                  child: child!,
                );
              },
              child: textContent,
            )
          // Static container: uses stored highlight colour (or transparent).
          : _buildContainer(
              color: _highlightBgColor(highlightColorIndex),
              shadow1Color: Colors.transparent,
              shadow1Blur: 0,
              shadow2Color: Colors.transparent,
              shadow2Blur: 0,
              shadow2Spread: 0,
              isBookmarked: isBookmarked,
              borderColor: scheme.secondary,
              showShadow: false,
              child: textContent,
            ),
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  /// Builds the verse number + text content, with an optional note indicator.
  Widget _buildVerseText(
      BuildContext context, ColorScheme scheme, bool hasNote) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
        if (hasNote)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Icon(
              Icons.edit_note_rounded,
              size: 16,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }

  /// Returns a semi-transparent background tint for the stored highlight.
  Color _highlightBgColor(int? colorIndex) {
    if (colorIndex == null) return Colors.transparent;
    return Color(AppDatabase.highlightColorValues[colorIndex])
        .withValues(alpha: 0.35);
  }

  Widget _buildContainer({
    required Color color,
    required Color shadow1Color,
    required double shadow1Blur,
    required Color shadow2Color,
    required double shadow2Blur,
    required double shadow2Spread,
    required bool isBookmarked,
    required Color borderColor,
    required bool showShadow,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: isBookmarked
            ? Border.all(color: borderColor, width: 1.5)
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: shadow1Color,
                  blurRadius: shadow1Blur,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: shadow2Color,
                  blurRadius: shadow2Blur,
                  spreadRadius: shadow2Spread,
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  // ── Long-press bottom sheet ─────────────────────────────────────────────────

  void _showVerseOptions(
    BuildContext context, {
    required bool isBookmarked,
    required int? highlightColorIndex,
    required String? currentNote,
    required int? bookmarkId,
  }) {
    final repo = ref.read(bibleRepositoryProvider);
    final highlightsDao = ref.read(highlightsDaoProvider);
    final bookAsync = ref.read(bookProvider(widget.bookId));
    final chapterAsync = ref.read(chapterProvider(widget.chapterId));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Bookmark toggle ──────────────────────────────────────────
            ListTile(
              leading: Icon(
                isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
              ),
              title: Text(
                isBookmarked ? 'Remover favorito' : 'Adicionar aos favoritos',
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (isBookmarked && bookmarkId != null) {
                  await repo.removeBookmark(bookmarkId);
                } else {
                  await repo.addBookmark(widget.verse.id);
                }
                if (!mounted) return;
                ref.invalidate(isBookmarkedProvider(widget.verse.id));
                ref.invalidate(bookmarksProvider);
              },
            ),

            // ── Note ────────────────────────────────────────────────────
            ListTile(
              leading: Icon(
                currentNote?.isNotEmpty == true
                    ? Icons.edit_note_rounded
                    : Icons.note_add_outlined,
              ),
              title: Text(
                currentNote?.isNotEmpty == true
                    ? 'Editar nota'
                    : 'Adicionar nota',
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _showNoteDialog(
                  context,
                  isBookmarked: isBookmarked,
                  bookmarkId: bookmarkId,
                  currentNote: currentNote,
                );
              },
            ),

            // ── Highlight colour row ─────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.highlight, size: 20),
                  const SizedBox(width: 12),
                  const Text('Destacar:'),
                  const SizedBox(width: 12),
                  ...List.generate(
                    AppDatabase.highlightColorValues.length,
                    (i) {
                      final baseColor =
                          Color(AppDatabase.highlightColorValues[i]);
                      final isSelected = highlightColorIndex == i;
                      return GestureDetector(
                        onTap: () async {
                          Navigator.pop(sheetCtx);
                          if (highlightColorIndex != null) {
                            await highlightsDao.updateHighlight(
                                widget.verse.id, i);
                          } else {
                            await highlightsDao.addHighlight(
                                widget.verse.id, i);
                          }
                          if (!mounted) return;
                          ref.invalidate(
                              verseHighlightProvider(widget.verse.id));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.black54, width: 2.5)
                                : Border.all(
                                    color: Colors.black12, width: 1),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.black54)
                              : null,
                        ),
                      );
                    },
                  ),
                  if (highlightColorIndex != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await highlightsDao
                            .removeHighlight(widget.verse.id);
                        if (!mounted) return;
                        ref.invalidate(
                            verseHighlightProvider(widget.verse.id));
                      },
                      child: const Tooltip(
                        message: 'Remover destaque',
                        child: Icon(Icons.highlight_off,
                            size: 24, color: Colors.black45),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Copy ────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copiar'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final label = _buildVerseLabel(bookAsync, chapterAsync);
                await Clipboard.setData(
                  ClipboardData(
                    text: '$label — ${widget.verse.verseText}',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Versículo copiado'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),

            // ── Share ────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartilhar'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final label = _buildVerseLabel(bookAsync, chapterAsync);
                await Share.share(
                  '$label\n${widget.verse.verseText}\n\nBíblia Ave Maria',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Formats "[Book Ch:Verse]" from async provider snapshots.
  String _buildVerseLabel(
    AsyncValue<Book?> bookAsync,
    AsyncValue<Chapter?> chapterAsync,
  ) {
    final bookName = bookAsync.valueOrNull?.name ?? '';
    final chapterNum = chapterAsync.valueOrNull?.number ?? '';
    return '$bookName $chapterNum:${widget.verse.number}';
  }

  // ── Note dialog ─────────────────────────────────────────────────────────────
  //
  // O diálogo é um StatefulWidget separado (_NoteDialog) que gerencia o
  // TextEditingController internamente. Isso evita chamar noteCtrl.dispose()
  // enquanto o TextField ainda existe (durante a animação de saída do diálogo),
  // o que causava _dependents.isEmpty no Riverpod.
  //
  // showDialog<String> retorna null (Cancelar) ou o texto digitado (Salvar).
  // Toda lógica que usa `ref` fica aqui, após verificar `mounted`.

  Future<void> _showNoteDialog(
    BuildContext context, {
    required bool isBookmarked,
    required int? bookmarkId,
    required String? currentNote,
  }) async {
    final repo = ref.read(bibleRepositoryProvider);
    final db = ref.read(appDatabaseProvider);

    final note = await showDialog<String>(
      context: context,
      builder: (dlgCtx) => _NoteDialog(currentNote: currentNote),
    );

    // null → Cancelar pressionado (ou diálogo dispensado)
    if (note == null || !mounted) return;

    if (isBookmarked && bookmarkId != null) {
      await (db.update(db.bookmarks)
            ..where((b) => b.id.equals(bookmarkId)))
          .write(
        BookmarksCompanion(
          note: Value(note.isEmpty ? null : note),
        ),
      );
    } else {
      await repo.addBookmark(
        widget.verse.id,
        note: note.isEmpty ? null : note,
      );
      if (mounted) ref.invalidate(isBookmarkedProvider(widget.verse.id));
    }
    if (mounted) ref.invalidate(bookmarksProvider);
  }
}

// ---------------------------------------------------------------------------
// _ChapterCell
// ---------------------------------------------------------------------------

class _ChapterCell extends StatelessWidget {
  const _ChapterCell({
    required this.number,
    required this.isCurrent,
    required this.onTap,
  });

  final int number;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isCurrent ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NoteDialog
// ---------------------------------------------------------------------------
// StatefulWidget separado para que o TextEditingController seja descartado
// pelo próprio widget, não pelo chamador. Isso evita dispose() prematuro
// enquanto o TextField ainda existe durante a animação de saída do diálogo.
// Retorna String via Navigator.pop(context, text) ao salvar, null ao cancelar.

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({this.currentNote});
  final String? currentNote;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentNote ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nota do versículo'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Escreva sua nota aqui...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
