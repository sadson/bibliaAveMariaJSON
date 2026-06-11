import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScreenSplash extends StatefulWidget {
  const ScreenSplash({super.key});

  @override
  State<ScreenSplash> createState() => _ScreenSplashState();
}

class _ScreenSplashState extends State<ScreenSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textOffset;
  late final Animation<double> _bottomOpacity;

  static const _gold = Color(0xFFC8A84B);

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _iconOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
    );

    _iconScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _textOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.38, 0.72, curve: Curves.easeIn),
    );

    _textOffset = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.38, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    _bottomOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.60, 0.95, curve: Curves.easeIn),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2900), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF091629),
              Color(0xFF0F2347),
              Color(0xFF1A3A6B),
              Color(0xFF102040),
            ],
            stops: [0.0, 0.3, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Glow background ──────────────────────────────────────────
            AnimatedBuilder(
              animation: _iconOpacity,
              builder: (_, __) => CustomPaint(
                size: MediaQuery.sizeOf(context),
                painter: _AmbientGlow(_iconOpacity.value),
              ),
            ),

            // ── Cross pattern (subtle) ───────────────────────────────────
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _iconOpacity,
                builder: (_, __) => Opacity(
                  opacity: _iconOpacity.value * 0.07,
                  child: CustomPaint(painter: _CrossPattern()),
                ),
              ),
            ),

            // ── Scrollable centered content ──────────────────────────────
            // LayoutBuilder + SingleChildScrollView + ConstrainedBox(minHeight)
            // = centrado em telas grandes, scrollável em landscape sem overflow.
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),

                          // ── Bible icon ─────────────────────────────────
                          AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, __) => FadeTransition(
                              opacity: _iconOpacity,
                              child: ScaleTransition(
                                scale: _iconScale,
                                child: _BibleIconWidget(gold: _gold),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ── Divider ornament ───────────────────────────
                          AnimatedBuilder(
                            animation: _textOpacity,
                            builder: (_, __) => FadeTransition(
                              opacity: _textOpacity,
                              child: _OrnamentDivider(gold: _gold),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Quote ──────────────────────────────────────
                          AnimatedBuilder(
                            animation: _ctrl,
                            builder: (_, __) => Transform.translate(
                              offset: Offset(0, _textOffset.value),
                              child: FadeTransition(
                                opacity: _textOpacity,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 44),
                                  child: Column(
                                    children: [
                                      const Text(
                                        '"E o Verbo se fez carne\ne habitou entre nós."',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w300,
                                          height: 1.65,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        '— João  1:14',
                                        style: TextStyle(
                                          color: _gold.withValues(alpha: 0.90),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Espaço reservado para o rodapé ancorado
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── App name ancorado no rodapé ──────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _bottomOpacity,
                  builder: (_, __) => FadeTransition(
                    opacity: _bottomOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.transparent,
                                _gold.withValues(alpha: 0.5),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'BÍBLIA AVE MARIA',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              letterSpacing: 3.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bible icon widget ────────────────────────────────────────────────────────

class _BibleIconWidget extends StatelessWidget {
  const _BibleIconWidget({required this.gold});
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.20),
                  blurRadius: 48,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),
          // Outer ring
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: gold.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
          // Inner circle background
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  gold.withValues(alpha: 0.22),
                  gold.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: gold.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
          ),
          // Icon
          Icon(
            Icons.menu_book_rounded,
            size: 56,
            color: gold,
            shadows: [
              Shadow(
                color: gold.withValues(alpha: 0.6),
                blurRadius: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Ornament divider ─────────────────────────────────────────────────────────

class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider({required this.gold});
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              gold.withValues(alpha: 0.55),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.brightness_1, size: 5, color: gold.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Icon(Icons.brightness_1, size: 8, color: gold.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        Icon(Icons.brightness_1, size: 5, color: gold.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Container(
          width: 36,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              gold.withValues(alpha: 0.55),
              Colors.transparent,
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Custom painters ──────────────────────────────────────────────────────────

class _AmbientGlow extends CustomPainter {
  const _AmbientGlow(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity == 0) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    final paint = Paint()
      ..color = const Color(0xFFC8A84B).withValues(alpha: 0.08 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
    canvas.drawCircle(center, 180, paint);

    final paint2 = Paint()
      ..color = const Color(0xFF1A6BB5).withValues(alpha: 0.12 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.55), 220, paint2);
  }

  @override
  bool shouldRepaint(_AmbientGlow old) => old.opacity != opacity;
}

class _CrossPattern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFC8A84B);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 48.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(Offset(x - 6, y), Offset(x + 6, y), paint);
        canvas.drawLine(Offset(x, y - 6), Offset(x, y + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
