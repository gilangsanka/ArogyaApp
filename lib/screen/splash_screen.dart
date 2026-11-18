import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_screen.dart';

/// Warna sesuai konfigurasi Tailwind pada desain HTML.
class _C {
  static const surface = Color(0xFFF8F9FE);
  static const primary = Color(0xFF5341CD);
  static const primaryContainer = Color(0xFF6C5CE7);
  static const secondary = Color(0xFF006A67);
  static const secondaryFixed = Color(0xFF5AF9F3);
  static const tertiaryFixedDim = Color(0xFFC5C0FF);
  static const primaryFixedDim = Color(0xFFC6BFFF);
  static const onSurfaceVariant = Color(0xFF474554);
  static const teal = Color(0xFF00CEC9);
}

const String _logoUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuC3k1xztZLnhXGOvY-dYmkt6hw72FAVsG8ArtQ-sjYssyFyTCfrLG4HBg8x2zKahNu7oAGEYXfmssaa6sxhT5LaLu5yEDoMMEFC5d7SQQLfldqbrb9g33RTr2USfrXUDsavMrn3YB0ngGfj4fKwPgEWG5Hel3MFum7FA8oY1PbrBqU3Z9UqRnEp0DySPCgg2qNZPvkevc7Cgbi6jxyRjwv0yu13WSFkXxmccHMQLmlD_OkQmh0u0mGb';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onStart});

  /// Dipanggil setelah pengguna berhasil masuk (login/registrasi), atau langsung
  /// bila sesi login masih tersimpan. Tombol "Mulai" membuka halaman login.
  final VoidCallback? onStart;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _RippleData {
  _RippleData(this.id, this.position);
  final int id;
  final Offset position;
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  late final AnimationController _ecg = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  late final Animation<double> _logoScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.038), weight: 14),
    TweenSequenceItem(tween: Tween(begin: 1.038, end: 1.0), weight: 14),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.025), weight: 14),
    TweenSequenceItem(tween: Tween(begin: 1.025, end: 1.0), weight: 14),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 44),
  ]).animate(_heart);

  final List<_RippleData> _ripples = [];
  int _rippleId = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _heart.dispose();
    _ecg.dispose();
    _halo.dispose();
    super.dispose();
  }

  void _addRipple(PointerDownEvent e) {
    final id = _rippleId++;
    setState(() => _ripples.add(_RippleData(id, e.localPosition)));
    Future.delayed(const Duration(milliseconds: 760), () {
      if (!mounted) return;
      setState(() => _ripples.removeWhere((r) => r.id == id));
    });
  }

  /// Sudah login -> langsung lanjut. Belum -> buka halaman login.
  void _start() {
    if (Supabase.instance.client.auth.currentSession != null) {
      widget.onStart?.call();
      return;
    }
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => LoginScreen(
          onLoggedIn: () => widget.onStart?.call(),
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.surface,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _addRipple,
        child: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: Column(
                children: [
                  Expanded(child: Center(child: _buildHero())),
                  _buildBottom(),
                ],
              ),
            ),
            for (final r in _ripples)
              _TouchRipple(key: ValueKey(r.id), position: r.position),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Background: orb cahaya, gelembung & tanda plus melayang
  // ---------------------------------------------------------------------------
  Widget _buildBackground() {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          Widget orb(double size, Color color) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              );

          Widget bubble(double size, Color fill, {Color? border}) => Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: border == null
                      ? null
                      : Border.all(color: border, width: 1),
                ),
              );

          Widget cross(double size, Color color) => Text(
                '✚',
                style: TextStyle(
                    fontSize: size,
                    color: color,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none),
              );

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Orb besar
              Positioned(
                  top: -h * 0.10 - 100,
                  left: -w * 0.15 - 100,
                  child: orb(420, _C.primaryContainer.withValues(alpha: 0.18))),
              Positioned(
                  top: h * 0.40,
                  right: -w * 0.20 - 100,
                  child: orb(380, _C.secondaryFixed.withValues(alpha: 0.30))),
              Positioned(
                  bottom: -h * 0.10 - 80,
                  left: w * 0.10 - 60,
                  child: orb(340, _C.tertiaryFixedDim.withValues(alpha: 0.25))),

              // Halo berdenyut di atas tengah
              Positioned(
                top: -80,
                left: w / 2 - 160,
                child: AnimatedBuilder(
                  animation: _halo,
                  builder: (_, child) =>
                      Opacity(opacity: 0.5 + 0.5 * _halo.value, child: child),
                  child: orb(320, _C.primaryContainer.withValues(alpha: 0.22)),
                ),
              ),
              Positioned(
                  bottom: 96,
                  left: -64,
                  child: orb(288, _C.primaryFixedDim.withValues(alpha: 0.28))),

              // Gelembung vital
              Positioned(
                top: h * 0.16,
                left: w * 0.12,
                child: _Float(
                  seconds: 7,
                  child: bubble(28, _C.secondaryFixed.withValues(alpha: 0.40),
                      border: _C.secondaryFixed.withValues(alpha: 0.50)),
                ),
              ),
              Positioned(
                top: h * 0.28,
                right: w * 0.10,
                child: _Float(
                  seconds: 8.5,
                  delay: 1.2,
                  child: bubble(40, _C.primaryContainer.withValues(alpha: 0.20),
                      border: _C.primaryContainer.withValues(alpha: 0.30)),
                ),
              ),
              Positioned(
                bottom: h * 0.28,
                left: w * 0.08,
                child: _Float(
                  seconds: 6.8,
                  delay: 2,
                  child: bubble(32, _C.teal.withValues(alpha: 0.20),
                      border: _C.teal.withValues(alpha: 0.30)),
                ),
              ),
              Positioned(
                top: h * 0.52,
                left: w * 0.06,
                child: _Float(
                  seconds: 5.5,
                  delay: 0.7,
                  child:
                      bubble(16, _C.primaryContainer.withValues(alpha: 0.30)),
                ),
              ),
              Positioned(
                bottom: h * 0.22,
                right: w * 0.12,
                child: _Float(
                  seconds: 6.2,
                  delay: 1.8,
                  child: bubble(20, _C.secondary.withValues(alpha: 0.25)),
                ),
              ),

              // Tanda plus medis
              Positioned(
                top: h * 0.20,
                right: w * 0.18,
                child: _Float(
                    seconds: 9,
                    child:
                        cross(20, _C.primaryContainer.withValues(alpha: 0.25))),
              ),
              Positioned(
                top: h * 0.68,
                left: w * 0.18,
                child: _Float(
                    seconds: 7.5,
                    child: cross(14, _C.teal.withValues(alpha: 0.35))),
              ),
              Positioned(
                bottom: h * 0.36,
                right: w * 0.22,
                child: _Float(
                    seconds: 8,
                    child: cross(16, _C.primary.withValues(alpha: 0.20))),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero: logo + cincin radar + ECG + tagline
  // ---------------------------------------------------------------------------
  Widget _buildHero() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _RadarRing(
                  controller: _heart,
                  size: 176,
                  color: _C.secondaryFixed.withValues(alpha: 0.40),
                  delay: 0),
              _RadarRing(
                  controller: _heart,
                  size: 224,
                  color: _C.primaryContainer.withValues(alpha: 0.30),
                  delay: 0.9 / 3.2),
              _RadarRing(
                  controller: _heart,
                  size: 272,
                  color: _C.primary.withValues(alpha: 0.20),
                  delay: 1.8 / 3.2),
              // Glow di belakang logo
              Container(
                width: 280,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _C.primaryContainer.withValues(alpha: 0.25),
                      _C.secondary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              ScaleTransition(
                scale: _logoScale,
                child: Image.network(
                  _logoUrl,
                  width: 256,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.favorite_rounded,
                    size: 96,
                    color: _C.primaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 288,
          height: 56,
          child: AnimatedBuilder(
            animation: _ecg,
            builder: (_, __) =>
                CustomPaint(painter: _EcgPainter(progress: _ecg.value)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Layanan Kesehatan Digital',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            color: _C.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tombol utama
  // ---------------------------------------------------------------------------
  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C5CE7), Color(0xFF5341CD)],
            ),
            boxShadow: [
              BoxShadow(
                color: _C.primaryContainer.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _start,
              splashColor: Colors.white.withValues(alpha: 0.30),
              highlightColor: Colors.white.withValues(alpha: 0.10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mulai Konsultasi & Antrean',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget pendukung
// =============================================================================

/// Elemen yang melayang naik-turun sambil sedikit berputar (floatSlow).
class _Float extends StatefulWidget {
  const _Float({required this.seconds, this.delay = 0, required this.child});

  final double seconds;
  final double delay;
  final Widget child;

  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.seconds * 500).round()),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay <= 0) {
      _c.repeat(reverse: true);
    } else {
      _timer = Timer(
        Duration(milliseconds: (widget.delay * 1000).round()),
        () {
          if (mounted) _c.repeat(reverse: true);
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -14 * _a.value),
        child: Transform.rotate(
          angle: 4 * math.pi / 180 * _a.value,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Cincin gelombang radar (radarWave).
class _RadarRing extends StatelessWidget {
  const _RadarRing({
    required this.controller,
    required this.size,
    required this.color,
    required this.delay,
  });

  final AnimationController controller;
  final double size;
  final Color color;
  final double delay; // fraksi dari durasi total (0..1)

  static const _curve = Cubic(0.1, 0.4, 0.3, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final phase = (controller.value - delay) % 1.0;
        final t = _curve.transform(phase);
        final scale = 0.7 + 0.9 * t;
        final opacity = phase < 0.5
            ? 0.8 - 0.4 * (phase / 0.5)
            : 0.4 * (1 - (phase - 0.5) / 0.5);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Riak cahaya saat layar disentuh.
class _TouchRipple extends StatelessWidget {
  const _TouchRipple({super.key, required this.position});

  final Offset position;

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOut,
          builder: (_, t, child) => Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.scale(scale: 3.5 * t, child: child),
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _C.secondaryFixed.withValues(alpha: 0.5),
                  _C.primaryContainer.withValues(alpha: 0.2),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 0.75],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Garis detak jantung (ECG) dengan sapuan cahaya dan titik laser.
class _EcgPainter extends CustomPainter {
  _EcgPainter({required this.progress});

  final double progress;

  // Titik-titik dari viewBox SVG 280 x 48.
  static const _pts = <Offset>[
    Offset(0, 24),
    Offset(65, 24),
    Offset(75, 14),
    Offset(85, 34),
    Offset(98, 6),
    Offset(110, 42),
    Offset(122, 20),
    Offset(132, 26),
    Offset(142, 24),
    Offset(205, 24),
    Offset(214, 16),
    Offset(222, 32),
    Offset(230, 10),
    Offset(238, 38),
    Offset(246, 24),
    Offset(280, 24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 280;
    final sy = size.height / 48;

    final path = Path()..moveTo(_pts.first.dx * sx, _pts.first.dy * sy);
    for (final p in _pts.skip(1)) {
      path.lineTo(p.dx * sx, p.dy * sy);
    }

    // Jalur dasar (redup)
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.75
        ..color = _C.primary.withValues(alpha: 0.15),
    );

    final metric = path.computeMetrics().first;
    final len = metric.length;
    final window = len * 0.33;
    final head = progress * (len + window);
    final start = (head - window).clamp(0.0, len);
    final end = head.clamp(0.0, len);

    if (end > start) {
      final segment = metric.extractPath(start, end);
      final shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, 0),
        const [
          Color(0x1A6C5CE7),
          Color(0xB36C5CE7),
          Color(0xFF00CEC9),
          Color(0xFF00B894),
          Color(0x266C5CE7),
        ],
        const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

      // Glow
      canvas.drawPath(
        segment,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.75
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );
      // Garis tajam
      canvas.drawPath(
        segment,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 2.75
          ..shader = shader,
      );
    }

    // Titik laser di ujung sapuan
    if (head >= 0 && head <= len) {
      final tangent = metric.getTangentForOffset(head);
      if (tangent != null) {
        final fade = math.min(1.0, math.min(head / 20, (len - head) / 20));
        canvas.drawCircle(
          tangent.position,
          6,
          Paint()
            ..color = _C.teal.withValues(alpha: 0.8 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          tangent.position,
          3.2,
          Paint()..color = Colors.white.withValues(alpha: fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EcgPainter old) => old.progress != progress;
}
