import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/prefs_service.dart';
import 'settings_notifier.dart';

class ScreenSettings extends ConsumerStatefulWidget {
  const ScreenSettings({super.key});

  @override
  ConsumerState<ScreenSettings> createState() => _ScreenSettingsState();
}

class _ScreenSettingsState extends ConsumerState<ScreenSettings> {
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _fontSize = PrefsService.instance.getFontSize();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── Tema ────────────────────────────────────────────────────────────
          _SectionLabel('Tema'),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 18),
                label: Text('Sistema'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 18),
                label: Text('Claro'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 18),
                label: Text('Escuro'),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).setThemeMode(s.first),
          ),

          const SizedBox(height: 32),

          // ── Tamanho da fonte ─────────────────────────────────────────────────
          _SectionLabel('Tamanho da fonte'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.text_decrease, color: scheme.onSurfaceVariant),
              Expanded(
                child: Slider(
                  min: 13,
                  max: 26,
                  divisions: 13,
                  value: _fontSize,
                  label: '${_fontSize.toInt()}pt',
                  onChanged: (v) => setState(() => _fontSize = v),
                  onChangeEnd: (v) => PrefsService.instance.saveFontSize(v),
                ),
              ),
              Icon(Icons.text_increase, color: scheme.onSurfaceVariant),
            ],
          ),

          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visualização',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: _fontSize,
                      color: scheme.onSurface,
                      height: 1.7,
                    ),
                    children: [
                      TextSpan(
                        text: '1 ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _fontSize * 0.75,
                          color: scheme.primary,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'No princípio, Deus criou o céu e a terra.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.4,
          ),
    );
  }
}
