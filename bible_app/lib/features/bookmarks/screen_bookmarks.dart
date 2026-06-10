import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository/providers.dart';

class ScreenBookmarks extends ConsumerWidget {
  const ScreenBookmarks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: bookmarksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (bookmarks) {
          if (bookmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 72,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhum favorito ainda.\nPressione e segure um versículo para salvar.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bookmarks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final bm = bookmarks[i];
              return Dismissible(
                key: ValueKey(bm.bookmark.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) {
                  ref
                      .read(bibleRepositoryProvider)
                      .removeBookmark(bm.bookmark.id);
                },
                child: ListTile(
                  leading: const Icon(Icons.bookmark, color: Color(0xFFC8A84B)),
                  title: Text(
                    '${bm.book.name} ${bm.chapter.number}:${bm.verse.number}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  subtitle: Text(
                    bm.verse.verseText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => context.push(
                    '/books/${bm.book.id}/chapters/${bm.chapter.id}',
                    extra: bm.verse.id,
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 2),
    );
  }
}

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
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.menu_book), label: 'Livros'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Busca'),
        NavigationDestination(
            icon: Icon(Icons.bookmark), label: 'Favoritos'),
      ],
    );
  }
}
