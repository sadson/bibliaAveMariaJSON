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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: state.mode == SearchMode.text
                ? 'Buscar palavras...'
                : 'Busca semântica...',
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
          preferredSize: const Size.fromHeight(48),
          child: _ModeToggle(
            mode: state.mode,
            onModeChanged: (m) {
              ref.read(searchNotifierProvider.notifier).setMode(m);
              if (_controller.text.isNotEmpty) {
                ref
                    .read(searchNotifierProvider.notifier)
                    .search(_controller.text);
              }
            },
            semanticReady: state.embeddingServiceReady,
          ),
        ),
      ),
      body: state.isLoading
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
                  ? const Center(child: Text('Nenhum resultado encontrado'))
                  : state.results.isEmpty
                      ? _SearchHints(mode: state.mode)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: state.results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = state.results[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
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
                              onTap: () => context.push(
                                '/books/${r.book.id}/chapters/${r.chapter.id}',
                                extra: r.verse.id,
                              ),
                            );
                          },
                        ),
      bottomNavigationBar: _BottomNav(selectedIndex: 1),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onModeChanged,
    required this.semanticReady,
  });

  final SearchMode mode;
  final ValueChanged<SearchMode> onModeChanged;
  final bool semanticReady;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SegmentedButton<SearchMode>(
        segments: [
          const ButtonSegment(
            value: SearchMode.text,
            icon: Icon(Icons.text_fields, size: 18),
            label: Text('Texto'),
          ),
          ButtonSegment(
            value: SearchMode.semantic,
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('Semântica'),
            enabled: semanticReady,
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onModeChanged(s.first),
      ),
    );
  }
}

class _SearchHints extends StatelessWidget {
  const _SearchHints({required this.mode});
  final SearchMode mode;

  @override
  Widget build(BuildContext context) {
    final hints = mode == SearchMode.text
        ? ['amor', 'paz', 'oração', 'fé', 'graça']
        : ['Jesus cura um cego', 'criação do mundo', 'ressurreição dos mortos'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == SearchMode.text ? Icons.search : Icons.psychology,
              size: 56,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              mode == SearchMode.text
                  ? 'Busque por palavras no texto'
                  : 'Busque por conceitos e significados',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: hints
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
