import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'search_notifier.dart';

class ScreenSearch extends ConsumerStatefulWidget {
  const ScreenSearch({super.key});

  @override
  ConsumerState<ScreenSearch> createState() => _ScreenSearchState();
}

class _ScreenSearchState extends ConsumerState<ScreenSearch> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchNotifierProvider.notifier).search(value);
    });
  }

  void _fillAndSearch(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    ref.read(searchNotifierProvider.notifier).search(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final scheme = Theme.of(context).colorScheme;
    final queryActive = _controller.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Pesquisar na Bíblia...',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                ref.read(searchNotifierProvider.notifier).search('');
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _SearchModeIndicator(
            semanticReady: state.embeddingServiceReady,
            embeddingError: state.embeddingLoadError,
          ),
        ),
      ),
      body: Column(
        children: [
          if (state.refResult != null)
            _RefCard(
              ref: state.refResult!,
              onTap: () {
                ref.read(searchNotifierProvider.notifier).recordSearch();
                context.push(
                  '/books/${state.refResult!.book.id}/chapters/${state.refResult!.chapter.id}',
                  extra: state.refResult!.verse?.id,
                );
              },
            ),
          if (queryActive && state.results.isNotEmpty)
            _TestamentFilterChips(
              filter: state.testamentFilter,
              onChanged: (f) =>
                  ref.read(searchNotifierProvider.notifier).setTestamentFilter(f),
            ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            state.error!,
                            style: TextStyle(color: scheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : state.results.isEmpty && state.query.isNotEmpty
                        ? const Center(
                            child: Text('Nenhum resultado encontrado'))
                        : state.results.isEmpty
                            ? _SearchHints(
                                history: state.searchHistory,
                                onHistoryTap: _fillAndSearch,
                                onClearHistory: () => ref
                                    .read(searchNotifierProvider.notifier)
                                    .clearHistory(),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: state.results.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final r = state.results[i];
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 4),
                                    title: Text(
                                      '${r.book.name} ${r.chapter.number}:${r.verse.number}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      r.verse.verseText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                    ref
                                        .read(searchNotifierProvider.notifier)
                                        .recordSearch();
                                    context.push(
                                      '/books/${r.book.id}/chapters/${r.chapter.id}',
                                      extra: r.verse.id,
                                    );
                                  },
                                  );
                                },
                              ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: 1),
    );
  }
}

// ── Testament filter chips ─────────────────────────────────────────────────────

class _TestamentFilterChips extends StatelessWidget {
  const _TestamentFilterChips({
    required this.filter,
    required this.onChanged,
  });
  final TestamentFilter filter;
  final ValueChanged<TestamentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _chip(context, 'Todos', TestamentFilter.all),
            const SizedBox(width: 8),
            _chip(context, 'Antigo Testamento', TestamentFilter.at),
            const SizedBox(width: 8),
            _chip(context, 'Novo Testamento', TestamentFilter.nt),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, TestamentFilter value) {
    final selected = filter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Search history panel ───────────────────────────────────────────────────────

class _SearchHistory extends StatelessWidget {
  const _SearchHistory({
    required this.history,
    required this.onTap,
    required this.onClear,
  });
  final List<String> history;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Buscas recentes',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClear,
                child: const Text('Limpar'),
              ),
            ],
          ),
        ),
        ...history.map(
          (q) => ListTile(
            dense: true,
            leading: Icon(Icons.history, size: 18, color: scheme.onSurfaceVariant),
            title: Text(q),
            onTap: () => onTap(q),
          ),
        ),
      ],
    );
  }
}

// ── Reference navigation card ─────────────────────────────────────────────────

class _RefCard extends StatelessWidget {
  const _RefCard({required this.ref, required this.onTap});
  final RefResult ref;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasVerse = ref.verse != null;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.55),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                        fontSize: 14,
                      ),
                    ),
                    if (hasVerse) ...[
                      const SizedBox(height: 2),
                      Text(
                        ref.verse!.verseText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search mode indicator (read-only status chip) ────────────────────────────

class _SearchModeIndicator extends StatelessWidget {
  const _SearchModeIndicator({
    required this.semanticReady,
    this.embeddingError,
  });
  final bool semanticReady;
  final String? embeddingError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final IconData icon;
    final String label;
    final Color fg;

    if (semanticReady) {
      icon = Icons.psychology_outlined;
      label = 'Busca semântica';
      fg = scheme.primary;
    } else if (embeddingError != null) {
      icon = Icons.text_fields;
      label = 'Busca por texto (semântica indisponível)';
      fg = scheme.error;
    } else {
      icon = Icons.hourglass_top_rounded;
      label = 'Carregando busca semântica…';
      fg = scheme.onSurfaceVariant;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search hints / empty state ─────────────────────────────────────────────────

class _SearchHints extends StatelessWidget {
  const _SearchHints({
    required this.history,
    required this.onHistoryTap,
    required this.onClearHistory,
  });
  final List<String> history;
  final ValueChanged<String> onHistoryTap;
  final VoidCallback onClearHistory;

  static const _hints = [
    'Jesus e a mulher samaritana',
    'criação do mundo',
    'ressurreição',
    'amor ao próximo',
    'paz interior',
  ];

  @override
  Widget build(BuildContext context) {
    if (history.isNotEmpty) {
      return _SearchHistory(
        history: history,
        onTap: onHistoryTap,
        onClear: onClearHistory,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Busque por conceitos e significados',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _hints
                  .map(
                    (h) => ActionChip(
                      label: Text(h),
                      onPressed: () {},
                    ),
                  )
                  .toList(),
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
