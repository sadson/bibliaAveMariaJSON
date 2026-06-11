import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repository/providers.dart';
import '../../services/prefs_service.dart';

// ── Curated verse list: (bookId, chapterNumber, verseNumber) ──────────────────

const _curatedVerses = [
  (21, 23, 1),  // Sl 23:1
  (50, 3, 16),  // Jo 3:16
  (47, 5, 3),   // Mt 5:3
  (50, 14, 6),  // Jo 14:6
  (52, 8, 28),  // Rm 8:28
  (57, 4, 13),  // Fp 4:13
  (65, 11, 1),  // Hb 11:1
  (47, 22, 37), // Mt 22:37
  (21, 27, 1),  // Sl 27:1
  (50, 11, 25), // Jo 11:25
  (21, 91, 1),  // Sl 91:1
  (29, 40, 31), // Is 40:31
  (52, 12, 2),  // Rm 12:2
  (65, 13, 8),  // Hb 13:8
  (57, 4, 7),   // Fp 4:7
  (47, 6, 33),  // Mt 6:33
  (50, 8, 32),  // Jo 8:32
  (24, 3, 5),   // Pv 3:5
  (21, 46, 1),  // Sl 46:1
  (47, 11, 28), // Mt 11:28
];

// ── Daily verse data class ────────────────────────────────────────────────────

class _DailyVerseData {
  final Book book;
  final Chapter chapter;
  final Verse verse;

  const _DailyVerseData({
    required this.book,
    required this.chapter,
    required this.verse,
  });
}

// ── Daily verse provider ──────────────────────────────────────────────────────

final _dailyVerseProvider = FutureProvider<_DailyVerseData?>((ref) async {
  final doy = int.parse(DateFormat('D').format(DateTime.now()));
  final idx = doy % _curatedVerses.length;
  final (bookId, chapterNum, verseNum) = _curatedVerses[idx];

  final repo = ref.read(bibleRepositoryProvider);

  final book = await repo.getBook(bookId);
  if (book == null) return null;

  final chapter = await repo.findChapter(bookId, chapterNum);
  if (chapter == null) return null;

  final verse = await repo.findVerse(chapter.id, verseNum);
  if (verse == null) return null;

  return _DailyVerseData(book: book, chapter: chapter, verse: verse);
});

// ── ScreenBooks ───────────────────────────────────────────────────────────────

class ScreenBooks extends ConsumerWidget {
  const ScreenBooks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    final lastRead = PrefsService.instance.getLastRead();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia Ave Maria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configurações',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (books) {
          final at = books.where((b) => b.testament == 'AT').toList();
          final nt = books.where((b) => b.testament == 'NT').toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _DailyVerseCard(),
                ),
              ),
              if (lastRead != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _ContinueReadingCard(lastRead: lastRead),
                  ),
                ),
              _TestamentHeader('Antigo Testamento (${at.length} livros)'),
              _BooksList(at),
              _TestamentHeader('Novo Testamento (${nt.length} livros)'),
              _BooksList(nt),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          );
        },
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 0),
    );
  }
}

// ── Versículo do dia card ─────────────────────────────────────────────────────

class _DailyVerseCard extends ConsumerWidget {
  const _DailyVerseCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(_dailyVerseProvider);

    return dailyAsync.when(
      loading: () => _cardShell(
        context: context,
        child: const Center(
          heightFactor: 2,
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        final ref_ = '${data.book.name} ${data.chapter.number}:${data.verse.number}';

        return GestureDetector(
          onTap: () => context.push(
            '/books/${data.book.id}/chapters/${data.chapter.id}',
            extra: data.verse.id,
          ),
          child: _cardShell(
            context: context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories,
                        color: Colors.white.withValues(alpha: 0.9), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Versículo do dia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '“${data.verse.verseText}”',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.55,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    ref_,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cardShell({required BuildContext context, required Widget child}) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary,
            Color.lerp(primary, Colors.black, 0.28) ?? primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Continuar leitura card ────────────────────────────────────────────────────

class _ContinueReadingCard extends StatelessWidget {
  const _ContinueReadingCard({required this.lastRead});
  final LastRead lastRead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (lastRead.verseId != null) {
            context.push(
              '/books/${lastRead.bookId}/chapters/${lastRead.chapterId}',
              extra: lastRead.verseId,
            );
          } else {
            context.push(
              '/books/${lastRead.bookId}/chapters/${lastRead.chapterId}',
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_fill,
                color: scheme.onSecondaryContainer,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continuar leitura',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSecondaryContainer
                            .withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastRead.label,
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _TestamentHeader ──────────────────────────────────────────────────────────

class _TestamentHeader extends StatelessWidget {
  const _TestamentHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }
}

// ── _BooksList ────────────────────────────────────────────────────────────────

class _BooksList extends StatelessWidget {
  const _BooksList(this.books);
  final List<Book> books;

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: books.length,
      itemBuilder: (context, i) {
        final book = books[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              '${book.order}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(book.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/books/${book.id}/chapters'),
        );
      },
    );
  }
}

// ── _BottomNav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/');
          case 1:
            context.go('/search');
          case 2:
            context.go('/bookmarks');
          case 3:
            context.go('/highlights');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.menu_book), label: 'Livros'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Busca'),
        NavigationDestination(icon: Icon(Icons.bookmark), label: 'Favoritos'),
        NavigationDestination(icon: Icon(Icons.highlight), label: 'Destaques'),
      ],
    );
  }
}
