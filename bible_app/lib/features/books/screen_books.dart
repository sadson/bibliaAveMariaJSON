import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/repository/providers.dart';

class ScreenBooks extends ConsumerWidget {
  const ScreenBooks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bíblia Ave Maria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.go('/search'),
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
