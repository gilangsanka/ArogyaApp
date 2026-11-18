import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Helper animasi bersama (versi publik dari helper privat di
/// home_screen.dart / booking_screen.dart). Layar lama bisa dimigrasikan
/// pelan-pelan ke file ini.

/// Muncul dengan fade + geser + skala.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = 0,
    this.dx = 0,
    this.dy = 24,
    this.scaleFrom = 1,
  });

  final Widget child;
  final int delay;
  final double dx;
  final double dy;
  final double scaleFrom;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.delay == 0) {
      _c.forward();
    } else {
      _t = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) {
        final v = _a.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.dx * (1 - v), widget.dy * (1 - v)),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Menyusut sedikit saat ditekan.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key, required this.child, this.enabled = true, this.scale = 0.95});

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && widget.enabled ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Membesar-mengecil pelan ("bernapas").
class Breathe extends StatefulWidget {
  const Breathe(
      {super.key, required this.child, this.amount = 0.1, this.ms = 1600});

  final Widget child;
  final double amount;
  final int ms;

  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1 + widget.amount)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Melayang naik-turun pelan.
class Float extends StatefulWidget {
  const Float(
      {super.key,
      required this.child,
      this.dy = 4,
      this.ms = 2400,
      this.phase = 0});

  final Widget child;
  final double dy;
  final int ms;
  final double phase;

  @override
  State<Float> createState() => _FloatState();
}

class _FloatState extends State<Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
    value: widget.phase.clamp(0.0, 1.0),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -widget.dy * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * dx, 0, 0);
}

/// Teks gradien yang mengalir terus.
class FlowText extends StatefulWidget {
  const FlowText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<FlowText> createState() => _FlowTextState();
}

class _FlowTextState extends State<FlowText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child:
          Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) => LinearGradient(
          colors: const [
            AppColors.primary,
            AppColors.cyan,
            AppColors.primaryContainer,
          ],
          tileMode: TileMode.mirror,
          transform: _SlideGradient(_c.value * 2),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

/// Titik hijau berdenyut (ping).
class PulseDot extends StatefulWidget {
  const PulseDot(
      {super.key, required this.size, this.color = AppColors.success});

  final double size;
  final Color color;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.75 * (1 - _c.value),
              child: Transform.scale(
                scale: 1 + 1.2 * _c.value,
                child: Container(
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ),
            Container(
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Background: aurora orbs + partikel naik + parallax scroll.
// Harus ditaruh langsung di dalam Stack (mengembalikan Positioned.fill).
// -----------------------------------------------------------------------------
class _P {
  const _P(this.x, this.speed, this.size, this.phase);
  final double x;
  final int speed;
  final double size;
  final double phase;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t);

  final double t;

  static final List<_P> _ps = List.generate(18, (i) {
    final r = math.Random(i * 17 + 3);
    return _P(r.nextDouble(), 1 + r.nextInt(3), 1.8 + r.nextDouble() * 3,
        r.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _ps) {
      final prog = (t * p.speed + p.phase) % 1.0;
      final y = size.height * (1 - prog);
      final x = p.x * size.width + 14 * math.sin(prog * 2 * math.pi);
      final a = math.sin(prog * math.pi) * 0.35;
      paint.color = AppColors.primaryContainer.withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.scroll});

  final ValueListenable<double> scroll;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: LayoutBuilder(builder: (context, c) {
            return AnimatedBuilder(
              animation: Listenable.merge([_c, widget.scroll]),
              builder: (_, __) {
                final t = _c.value * 2 * math.pi;
                final s = widget.scroll.value;
                final h = c.maxHeight;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      top: -150 + 40 * math.sin(t) - s * 0.10,
                      left: -150 + 50 * math.cos(t),
                      child: _orb(380,
                          AppColors.primaryContainer.withValues(alpha: 0.18)),
                    ),
                    Positioned(
                      top: h * 0.35 + 50 * math.cos(t + 1) - s * 0.18,
                      right: -180 + 40 * math.sin(t + 2),
                      child: _orb(360,
                          AppColors.secondaryContainer.withValues(alpha: 0.25)),
                    ),
                    Positioned(
                      top: h * 0.70 + 40 * math.sin(t + 4) - s * 0.26,
                      left: -160 + 60 * math.cos(t + 3),
                      child:
                          _orb(320, AppColors.primary.withValues(alpha: 0.12)),
                    ),
                    Positioned(
                      top: h * 0.12 + 30 * math.sin(t + 5) - s * 0.14,
                      right: -130 + 30 * math.cos(t + 1),
                      child:
                          _orb(240, AppColors.tertiary.withValues(alpha: 0.10)),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: _ParticlePainter(_c.value)),
                    ),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
