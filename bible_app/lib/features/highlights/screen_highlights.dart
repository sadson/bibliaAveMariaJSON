import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/database.dart';
import '../../data/repository/providers.dart';

class ScreenHighlights extends ConsumerStatefulWidget {
  const ScreenHighlights({super.key});

  @override
  ConsumerState<ScreenHighlights> createState() => _ScreenHighlightsState();
}

class _ScreenHighlightsState extends ConsumerState<ScreenHighlights> {
  // null = show all colors
  int? _colorFilter;

  @override
  Widget build(BuildContext context) {
    final highlightsAsync = ref.watch(highlightsWithDetailsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Destaques')),
      body: Column(
        children: [
          _ColorFilterBar(
            selected: _colorFilter,
            onChanged: (c) => setState(() => _colorFilter = c),
          ),
          Expanded(
            child: highlightsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (all) {
                final items = _colorFilter == null
                    ? all
                    : all
                        .where((h) => h.highlight.colorIndex == _colorFilter)
                        .toList();

                if (items.isEmpty) {
                  return _EmptyState(hasFilter: _colorFilter != null);
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      _HighlightTile(item: items[i]),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 3),
    );
  }
}

// ── Color filter bar ──────────────────────────────────────────────────────────

class _ColorFilterBar extends StatelessWidget {
  const _ColorFilterBar({required this.selected, required this.onChanged});
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilterChip(
              label: const Text('Todos'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
              visualDensity: VisualDensity.compact,
            ),
            ...List.generate(AppDatabase.highlightColorValues.length, (i) {
              final color = Color(AppDatabase.highlightColorValues[i]);
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _ColorChip(
                  color: color,
                  selected: selected == i,
                  onTap: () => onChanged(selected == i ? null : i),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.black54 : Colors.black12,
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.black54)
            : null,
      ),
    );
  }
}

// ── Highlight tile ─────────────────────────────────────────────────────────────

class _HighlightTile extends ConsumerWidget {
  const _HighlightTile({required this.item});
  final HighlightWithDetails item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dao = ref.read(highlightsDaoProvider);
    final scheme = Theme.of(context).colorScheme;
    final highlightColor =
        Color(AppDatabase.highlightColorValues[item.highlight.colorIndex]);

    return Dismissible(
      key: ValueKey(item.highlight.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.errorContainer,
        child: Icon(Icons.delete, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        dao.removeHighlight(item.verse.id);
        ref.invalidate(verseHighlightProvider(item.verse.id));
      },
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: highlightColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
        ),
        title: Text(
          '${item.book.name} ${item.chapter.number}:${item.verse.number}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.primary,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          item.verse.verseText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => context.push(
          '/books/${item.book.id}/chapters/${item.chapter.id}',
          extra: item.verse.id,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.highlight,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter
                  ? 'Nenhum destaque com essa cor.'
                  : 'Nenhum versículo destacado ainda.\nPressione e segure um versículo para destacá-lo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

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
