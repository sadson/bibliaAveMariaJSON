import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository/providers.dart';

class ScreenChapters extends ConsumerWidget {
  const ScreenChapters({super.key, required this.bookId});
  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookProvider(bookId));
    final chaptersAsync = ref.watch(chaptersProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: bookAsync.when(
          data: (b) => Text(b?.name ?? ''),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Capítulos'),
        ),
      ),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (chapters) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 72,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: chapters.length,
          itemBuilder: (context, i) {
            final chapter = chapters[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  context.push('/books/$bookId/chapters/${chapter.id}'),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${chapter.number}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
