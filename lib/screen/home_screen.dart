import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';
import 'doctor_schedule_screen.dart';
import 'e_prescription_screen.dart';
import 'first_aid_screen.dart';
import 'med_reminder_screen.dart';
import 'medical_record_screen.dart';
import 'notification_screen.dart';
import 'pharmacy_status_screen.dart';
import '../services/clinic_repository.dart';
import '../utils/format.dart' show ymd, wibToday;
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

const String _logoUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDLNX3GmNr1aP2bzMdDlqZBRZkBPPbFgYSjjAEzzP7lUldJLt9htlQSvI3qjHZX5F42lmNmirW2HGlC4FLSLwPQ8esKxMZ8zqNmjGuW_44v_6C84MBXmRCbkWA9ARDlJetQSj4nC15sypbDs8X_8oraXqaZzVdULaiDIOJpvpTf89taHJZ7qP_7YgnZNShMn95-RlmyFZH9QZr-L7euXG50IQgFHawzqzx9BTKy8-aHYuw2jT-3HvyA';

// =============================================================================
// Helper animasi khusus Beranda (helper umum ada di widgets/anim.dart)
// =============================================================================

/// Membagikan notifier scroll ke widget di bawahnya (dipakai _InView).
class _ScrollScope extends InheritedWidget {
  const _ScrollScope({required this.scroll, required super.child});

  final ValueListenable<double> scroll;

  @override
  bool updateShouldNotify(_ScrollScope old) => scroll != old.scroll;
}

/// Memicu animasi SEKALI ketika widget masuk ke area layar.
class _InView extends StatefulWidget {
  const _InView({
    required this.builder,
    this.delay = 0,
    this.ms = 700,
    this.curve = Curves.easeOutCubic,
  });

  final Widget Function(BuildContext context, Animation<double> anim) builder;
  final int delay;
  final int ms;
  final Curve curve;

  @override
  State<_InView> createState() => _InViewState();
}

class _InViewState extends State<_InView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.ms),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: widget.curve);

  ValueListenable<double>? _scroll;
  Timer? _t;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = context.getInheritedWidgetOfExactType<_ScrollScope>()?.scroll;
    if (s != _scroll) {
      _scroll?.removeListener(_check);
      _scroll = s;
      _scroll?.addListener(_check);
    }
  }

  void _check() {
    if (_fired || !mounted) return;
    // Tanpa scope scroll -> langsung tampil.
    if (_scroll == null) {
      _fire();
      return;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final h = MediaQuery.sizeOf(context).height;
    if (top < h - 40) _fire();
  }

  void _fire() {
    _fired = true;
    _scroll?.removeListener(_check);
    _t = Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _scroll?.removeListener(_check);
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _a);
}

/// Fade + geser + skala, dipicu saat widget masuk layar karena scroll.
class _ScrollReveal extends StatelessWidget {
  const _ScrollReveal({
    required this.child,
    this.delay = 0,
    this.dx = 0,
    this.dy = 32,
    this.scaleFrom = 0.94,
    this.ms = 700,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final int delay;
  final double dx;
  final double dy;
  final double scaleFrom;
  final int ms;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return _InView(
      delay: delay,
      ms: ms,
      curve: curve,
      builder: (_, a) => AnimatedBuilder(
        animation: a,
        child: child,
        builder: (_, c) {
          final v = a.value;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx * (1 - v), dy * (1 - v)),
              child: Transform.scale(
                scale: scaleFrom + (1 - scaleFrom) * v,
                child: c,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bergeser kiri-kanan pelan (petunjuk "geser").
class _Nudge extends StatefulWidget {
  const _Nudge({required this.child, this.dx = 5});

  final Widget child;
  final double dx;

  @override
  State<_Nudge> createState() => _NudgeState();
}

class _NudgeState extends State<_Nudge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
        offset: Offset(widget.dx * Curves.easeInOut.transform(_c.value), 0),
        child: child,
      ),
    );
  }
}

/// Teks yang diketik huruf demi huruf (tanpa layout bergeser).
class _Typewriter extends StatefulWidget {
  const _Typewriter(this.text,
      {required this.style, this.delay = 0, this.cps = 60});

  final String text;
  final TextStyle style;
  final int delay; // ms
  final int cps; // karakter per detik

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
        milliseconds: (widget.text.length * 1000 / widget.cps).round()),
  );
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
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
      animation: _c,
      builder: (_, __) {
        final n = (_c.value * widget.text.length).floor();
        return Text.rich(
          TextSpan(children: [
            TextSpan(text: widget.text.substring(0, n)),
            TextSpan(
              text: widget.text.substring(n),
              style: const TextStyle(color: Colors.transparent),
            ),
          ]),
          style: widget.style,
        );
      },
    );
  }
}

/// Cincin radar yang memancar dari ikon (live monitor).
class _RadarIcon extends StatefulWidget {
  const _RadarIcon({required this.child});

  final Widget child;

  @override
  State<_RadarIcon> createState() => _RadarIconState();
}

class _RadarIconState extends State<_RadarIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _ring(double phase) {
    final p = (_c.value + phase) % 1.0;
    return Opacity(
      opacity: 0.5 * (1 - p),
      child: Transform.scale(
        scale: 1 + 1.2 * p,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [_ring(0), _ring(0.5), child!],
        ),
      ),
    );
  }
}

// =============================================================================
// Beranda pasien.
// [onNavigate]: 0 = Beranda, 1 = Booking, 2 = Antrean, 3 = Profil.
// [onBookDoctor]: dipanggil tombol "Booking" di kartu dokter dengan
//   (indeks poli, indeks dokter) sesuai data di booking_screen.dart.
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate, this.onBookDoctor});

  final ValueChanged<int> onNavigate;
  final void Function(int poli, int doc)? onBookDoctor;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  // Urutan sama dengan _DoctorList._doctors (Kevin, Nadya, Dimas)
  // -> (indeks poli, indeks dokter) di booking_screen.dart.
  static const _doctorTargets = <(int, int)>[(3, 0), (2, 0), (1, 0)];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _scroll.value = _ctrl.hasClients ? math.max(0.0, _ctrl.offset) : 0;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Booking ke (indeks poli, indeks dokter) tertentu.
  void _bookTarget(int poli, int doc) {
    final cb = widget.onBookDoctor;
    if (cb != null) {
      cb(poli, doc);
    } else {
      widget.onNavigate(1);
    }
  }

  void _bookDoctor(int i) {
    final t = _doctorTargets[i];
    _bookTarget(t.$1, t.$2);
  }

  /// Membuka halaman layanan dari menu grid.
  void _openMenu(_MenuTarget t) {
    final Widget page = switch (t) {
      _MenuTarget.jadwal => DoctorScheduleScreen(onBook: _bookTarget),
      _MenuTarget.panduan => const FirstAidScreen(),
      _MenuTarget.pengingat => const MedReminderScreen(),
      _MenuTarget.rekamMedis => const MedicalRecordScreen(),
      _MenuTarget.resep => const EPrescriptionScreen(),
      _MenuTarget.farmasi => const PharmacyStatusScreen(),
    };
    pushPage(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final onNavigate = widget.onNavigate;
    return Stack(
      children: [
        AuroraBackground(scroll: _scroll),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Reveal(dy: -24, child: _Header(scroll: _scroll)),
              Expanded(
                child: _ScrollScope(
                  scroll: _scroll,
                  child: ListView(
                    controller: _ctrl,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      // Hero memudar & mengecil sedikit saat di-scroll (parallax)
                      ValueListenableBuilder<double>(
                        valueListenable: _scroll,
                        builder: (_, s, child) => Opacity(
                          opacity: (1 - s / 700).clamp(0.4, 1.0),
                          child: Transform.scale(
                            scale: 1 - (s / 1400).clamp(0.0, 0.05),
                            alignment: Alignment.topCenter,
                            child: child,
                          ),
                        ),
                        child: Reveal(
                          delay: 80,
                          dy: 36,
                          scaleFrom: 0.96,
                          child: _Hero(onBooking: () => onNavigate(1)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Reveal(
                        delay: 240,
                        dy: 34,
                        child: _QueueCard(onOpen: () => onNavigate(2)),
                      ),
                      const SizedBox(height: 16),
                      Reveal(
                        delay: 360,
                        child: _SearchBar(onTap: () => onNavigate(1)),
                      ),
                      const SizedBox(height: 20),
                      const _ScrollReveal(
                        dx: -16,
                        dy: 0,
                        child: _SectionTitle('Menu Layanan'),
                      ),
                      const SizedBox(height: 10),
                      _MenuGrid(onOpen: _openMenu),
                      const SizedBox(height: 20),
                      _ScrollReveal(
                        child: _MedReminderCard(
                          onOpen: () =>
                              pushPage(context, const MedReminderScreen()),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _ScrollReveal(
                        dx: -16,
                        dy: 0,
                        child: _SectionTitle(
                          'Jadwal Dokter Hari Ini',
                          trailing: 'Geser →',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DoctorList(onBooking: _bookDoctor),
                      const SizedBox(height: 20),
                      _ScrollReveal(
                        child: _FirstAidCard(
                          onOpen: () =>
                              pushPage(context, const FirstAidScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Header
// =============================================================================
class _Header extends StatelessWidget {
  const _Header({required this.scroll});

  final ValueListenable<double> scroll;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scroll,
      builder: (_, s, child) {
        final k = (s / 50).clamp(0.0, 1.0);
        return Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.82 + 0.12 * k),
            border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.7))),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10 * k),
                blurRadius: 18 * k,
                offset: Offset(0, 6 * k),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Float(
            dy: 3,
            ms: 2600,
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.network(
                _logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_hospital_rounded,
                    color: AppColors.primaryContainer,
                    size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Arogya',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                    FlowText('App',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                    const SizedBox(width: 6),
                    const PulseDot(size: 8),
                  ],
                ),
                Text('Layanan Kesehatan Digital',
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Pressable(
            scale: 0.88,
            child: InkWell(
              onTap: () => pushPage(context, const NotificationScreen()),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const _RingingBell(),
                    Positioned(
                      top: 8,
                      right: 9,
                      child: Breathe(
                        amount: 0.35,
                        ms: 900,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lonceng yang bergoyang tiap beberapa detik.
class _RingingBell extends StatefulWidget {
  const _RingingBell();

  @override
  State<_RingingBell> createState() => _RingingBellState();
}

class _RingingBellState extends State<_RingingBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
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
      builder: (_, __) {
        final t = _c.value;
        double angle = 0;
        if (t < 0.2) {
          final p = t / 0.2;
          angle = math.sin(p * math.pi * 6) * (1 - p) * 0.4;
        }
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.topCenter,
          child: const Icon(Icons.notifications_none_rounded,
              size: 20, color: AppColors.primary),
        );
      },
    );
  }
}

// =============================================================================
// Hero (border gradien berputar + ikon melayang + efek ketik)
// =============================================================================
class _Hero extends StatefulWidget {
  const _Hero({required this.onBooking});

  final VoidCallback onBooking;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Widget _bubble(IconData icon, Color color) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: color),
      );

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: glassDecoration(radius: 26.5, opacity: 0.6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ikon medis melayang (pojok kanan atas)
            Positioned(
              top: -6,
              right: -6,
              child: SizedBox(
                width: 90,
                height: 36,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Float(
                        dy: 5,
                        ms: 2000,
                        child: _bubble(Icons.favorite_rounded, AppColors.error),
                      ),
                    ),
                    Positioned(
                      right: 32,
                      top: 6,
                      child: Float(
                        dy: 4,
                        ms: 2600,
                        phase: 0.5,
                        child: _bubble(
                            Icons.monitor_heart_rounded, AppColors.cyan),
                      ),
                    ),
                    Positioned(
                      right: 64,
                      top: 0,
                      child: Float(
                        dy: 6,
                        ms: 3000,
                        phase: 0.25,
                        child: _bubble(Icons.add_rounded, AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Reveal(
                  delay: 300,
                  dx: -20,
                  dy: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulseDot(size: 8),
                        const SizedBox(width: 6),
                        Text('Buka Hari Ini • 07:00 - 21:00',
                            style: appText(11,
                                w: FontWeight.w700, c: AppColors.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  delay: 380,
                  dy: 18,
                  child: Text('Kesehatan Terpercaya,',
                      style: appText(23, w: FontWeight.w700, h: 1.2, ls: -0.4)),
                ),
                Reveal(
                  delay: 460,
                  dy: 18,
                  child: FlowText('Tanpa Antre Lama',
                      style: appText(23, w: FontWeight.w700, h: 1.2, ls: -0.4)),
                ),
                const SizedBox(height: 8),
                _Typewriter(
                  'Booking poli, pantau giliran antrean secara real-time, '
                  'lihat jadwal dokter, dan akses resep serta rekam medis '
                  'digital Anda.',
                  delay: 800,
                  cps: 70,
                  style: appText(13, c: AppColors.onSurfaceVariant, h: 1.5),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(
                      child: Reveal(
                        delay: 620,
                        dy: 22,
                        scaleFrom: 0.75,
                        child: _MiniFeature(
                            icon: Icons.sensors_rounded,
                            label: 'Antrean\nReal-time'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Reveal(
                        delay: 730,
                        dy: 22,
                        scaleFrom: 0.75,
                        child: _MiniFeature(
                            icon: Icons.receipt_long_rounded,
                            label: 'E-Resep\nDigital'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Reveal(
                        delay: 840,
                        dy: 22,
                        scaleFrom: 0.75,
                        child: _MiniFeature(
                            icon: Icons.folder_shared_rounded,
                            label: 'Rekam\nMedis'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Reveal(
                  delay: 960,
                  dy: 22,
                  child: _GradientButton(
                    label: 'Booking Pemeriksaan',
                    icon: Icons.arrow_forward_rounded,
                    onTap: widget.onBooking,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _spin,
      child: inner,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: SweepGradient(
            transform: GradientRotation(_spin.value * 2 * math.pi),
            colors: [
              AppColors.primary.withValues(alpha: 0.9),
              AppColors.cyan.withValues(alpha: 0.12),
              AppColors.tertiary.withValues(alpha: 0.7),
              AppColors.cyan.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.9),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.18),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Breathe(
            amount: 0.14,
            ms: 1800,
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: appText(10,
                  w: FontWeight.w600, c: AppColors.onSurfaceVariant, h: 1.3)),
        ],
      ),
    );
  }
}

/// Tombol gradien dengan kilau menyapu + panah bergerak.
class _GradientButton extends StatefulWidget {
  const _GradientButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            splashColor: Colors.white.withValues(alpha: 0.3),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (_, __) {
                        final p = (_c.value / 0.55).clamp(0.0, 1.0);
                        return FractionallySizedBox(
                          alignment: Alignment(-1.5 + 3 * p, 0),
                          widthFactor: 0.28,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label,
                          style:
                              appText(13, w: FontWeight.w700, c: Colors.white)),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _c,
                        builder: (_, child) => Transform.translate(
                          offset:
                              Offset(2.5 * math.sin(_c.value * math.pi * 4), 0),
                          child: child,
                        ),
                        child: Icon(widget.icon, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Antrean live per poli
// =============================================================================
class _QueueInfo {
  const _QueueInfo(
      this.name, this.icon, this.eta, this.prefix, this.color, this.bg);
  final String name;
  final IconData icon;
  final String eta;
  final String prefix;
  final Color color;
  final Color bg;
}

class _QueueCard extends StatefulWidget {
  const _QueueCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  static const _palette = <(Color, Color, IconData)>[
    (AppColors.primary, AppColors.primaryFixed, Icons.medical_services_rounded),
    (AppColors.secondary, Color(0x665AF9F3), Icons.mood_rounded),
    (AppColors.tertiary, Color(0xFFE3DFFF), Icons.child_care_rounded),
  ];

  // Data kartu: papan antrean per poli + booking aktif milik pasien.
  List<Json>? _board;
  bool _boardError = false;
  List<Json> _mine = const [];
  bool _loading = true;
  RealtimeChannel? _channel;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // Booking baru / perubahan antrean langsung memperbarui kartu ini.
    _channel = ClinicRepository.instance
        .listen('home_queue_appts', 'appointments', _load);
    // Cadangan bila realtime belum aktif untuk tabel appointments.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    final ch = _channel;
    if (ch != null) ClinicRepository.instance.unlisten(ch);
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ClinicRepository.instance;
    List<Json>? board;
    var boardError = false;
    List<Json> mine = const [];
    try {
      board = await repo.queueBoard(DateTime.now());
    } catch (e) {
      boardError = true;
      debugPrint('get_queue_board gagal: $e');
    }
    try {
      mine = await repo.activeAppointments();
    } catch (e) {
      mine = const [];
      debugPrint('activeAppointments gagal: $e');
    }
    if (!mounted) return;
    setState(() {
      _board = board;
      _boardError = boardError;
      _mine = mine;
      _loading = false;
    });
  }

  /// Baris antrean milik pasien dari booking aktif.
  Widget _myRow(Json appt) {
    final poli = (appt['polyclinics'] as Map?) ?? const {};
    final number = (appt['queue_number'] as num?)?.toInt() ?? 0;
    final prefix = (appt['queue_prefix'] ?? '').toString();
    final label = (appt['queue_label'] ??
            (number > 0 ? '$prefix-${number.toString().padLeft(3, '0')}' : '—'))
        .toString();
    final isToday = (appt['appt_date'] ?? '').toString() == ymd(wibToday());

    // Cocokkan dengan papan antrean poli yang sama (bila papan berhasil dimuat).
    Json? b;
    for (final r in _board ?? const <Json>[]) {
      if (r['polyclinic_id'] == appt['polyclinic_id']) b = r;
    }
    final current = (b?['current_number'] as num?)?.toInt() ?? 0;
    // Rata-rata menit per pasien murni dari database (get_queue_board).
    final avg = b?['avg_minutes'] as num?;
    // Jumlah pasien di depan: selisih nomor Anda dengan nomor yang sedang
    // dilayani (jika belum ada yang dilayani, semua nomor sebelum Anda).
    final ahead = current > 0 ? number - current : number - 1;

    String eta;
    String etaPrefix = 'Estimasi tunggu';
    if (!isToday) {
      // Booking untuk hari lain: tampilkan jadwalnya.
      final d = (appt['appt_date'] ?? '').toString(); // yyyy-MM-dd
      final t = (appt['appt_time'] ?? '').toString();
      final dd =
          d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;
      final tt = t.length >= 5 ? t.substring(0, 5) : t;
      etaPrefix = 'Jadwal';
      eta = '$dd · $tt';
    } else if (ahead <= 0) {
      eta = 'segera';
    } else if (avg == null) {
      eta = '—'; // database belum memberi rata-rata menit
    } else {
      eta = '~${(ahead * avg).round()} mnt';
    }
    final progress = isToday && number > 0 && current > 0
        ? (current / number).clamp(0.05, 1.0).toDouble()
        : 0.15;

    return _QueueRow(
      info: _QueueInfo(
        (poli['name'] ?? 'Poliklinik').toString(),
        _palette[0].$3,
        eta,
        prefix,
        _palette[0].$1,
        _palette[0].$2,
      ),
      number: label,
      progress: progress,
      caption: 'Antrean Anda',
      etaPrefix: etaPrefix,
    );
  }

  String _queueLabel(Json row) {
    final prefix = (row['queue_prefix'] ?? '').toString();
    final number = (row['current_number'] ?? 0) as int;
    return number <= 0 || prefix.isEmpty
        ? '—'
        : '$prefix-${number.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(radius: 28, opacity: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RadarIcon(
                  child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success.withValues(alpha: 0.15)),
                      child: const Icon(Icons.sensors_rounded,
                          size: 17, color: AppColors.success))),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text('LIVE MONITOR',
                          style: appText(10,
                              w: FontWeight.w700,
                              c: AppColors.success,
                              ls: 0.8)),
                      const SizedBox(width: 6),
                      const PulseDot(size: 7)
                    ]),
                    Text('Antrean Poliklinik',
                        style: appText(15, w: FontWeight.w700)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('Realtime',
                      style: appText(11, c: AppColors.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              if (_loading) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final mine = _mine;
              final rows = _board ?? const <Json>[];
              if (mine.isEmpty && _boardError) {
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Data antrean belum dapat dimuat.',
                        style: appText(11, c: AppColors.onSurfaceVariant)));
              }
              if (mine.isEmpty && rows.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada data antrean hari ini.',
                        style: appText(11, c: AppColors.onSurfaceVariant)));
              }
              return Column(children: [
                for (final appt in mine) ...[
                  _myRow(appt),
                  const SizedBox(height: 8),
                ],
                for (var i = 0; i < rows.length; i++) ...[
                  Reveal(
                      delay: 400 + i * 100,
                      dx: 28,
                      dy: 0,
                      child: _QueueRow(
                        info: _QueueInfo(
                          (rows[i]['name'] ?? 'Poliklinik').toString(),
                          _palette[i % _palette.length].$3,
                          (rows[i]['waiting'] ?? 0) > 0 &&
                                  rows[i]['avg_minutes'] != null
                              ? '~${((rows[i]['waiting'] as num) * (rows[i]['avg_minutes'] as num)).round()} mnt'
                              : '—',
                          (rows[i]['queue_prefix'] ?? '').toString(),
                          _palette[i % _palette.length].$1,
                          _palette[i % _palette.length].$2,
                        ),
                        number: _queueLabel(rows[i]),
                        progress:
                            ((rows[i]['waiting'] as num?)?.toDouble() ?? 0) > 0
                                ? 0.65
                                : 0.15,
                      )),
                  const SizedBox(height: 8),
                ],
              ]);
            },
          ),
          const Divider(height: 16, color: Colors.white),
          Pressable(
              scale: 0.97,
              child: InkWell(
                  onTap: widget.onOpen,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Text('Lihat Status Antrean Saya',
                            style: appText(12,
                                w: FontWeight.w700, c: AppColors.primary)),
                        const SizedBox(width: 4),
                        const _Nudge(
                            dx: 4,
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 14, color: AppColors.primary))
                      ])))),
        ],
      ),
    );
  }
}

class _QueueRow extends StatefulWidget {
  const _QueueRow(
      {required this.info,
      required this.number,
      required this.progress,
      this.caption = 'Sedang diperiksa',
      this.etaPrefix = 'Estimasi tunggu'});

  final _QueueInfo info;
  final String number;
  final double progress;
  final String caption;
  final String etaPrefix;

  @override
  State<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends State<_QueueRow>
    with SingleTickerProviderStateMixin {
  // value: 1 = tidak sedang berkedip
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant _QueueRow old) {
    super.didUpdateWidget(old);
    if (old.number != widget.number) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return AnimatedBuilder(
      animation: _flash,
      builder: (_, child) {
        final k = 1 - Curves.easeOut.transform(_flash.value);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white.withValues(alpha: 0.85),
                info.color.withValues(alpha: 0.2), k),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Color.lerp(Colors.white.withValues(alpha: 0.7),
                  info.color.withValues(alpha: 0.55), k)!,
            ),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          // Ikon dengan cincin progres yang bergerak mengikuti antrean
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: widget.progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      color: info.color,
                      backgroundColor: info.color.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: info.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info.icon, size: 19, color: info.color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name, style: appText(13, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Breathe(
                      amount: 0.6,
                      ms: 1000,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: info.color, shape: BoxShape.circle),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('${widget.etaPrefix} ${info.eta}',
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(widget.caption,
                  style: appText(10, c: AppColors.onSurfaceVariant)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerRight,
                  children: [...previous, if (current != null) current],
                ),
                transitionBuilder: (child, anim) => ClipRect(
                  child: FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.7), end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                ),
                child: Text(
                  widget.number,
                  key: ValueKey(widget.number),
                  style:
                      appText(17, w: FontWeight.w700, c: info.color, ls: -0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Search (placeholder berganti + glow bernapas)
// =============================================================================
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar>
    with SingleTickerProviderStateMixin {
  static const _hints = <String>[
    'Cari dokter atau poliklinik...',
    'Coba: Poli Gigi & Mulut',
    'Coba: dr. Nadya Alika',
    'Coba: Penyakit Dalam',
  ];

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _hints.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_glow.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.04 + 0.12 * v),
                  blurRadius: 10 + 12 * v,
                ),
              ],
            ),
            child: child,
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
            child: Row(
              children: [
                const Breathe(
                  amount: 0.12,
                  ms: 1800,
                  child: Icon(Icons.search_rounded,
                      size: 19, color: AppColors.outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.4), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _hints[_i],
                      key: ValueKey(_i),
                      style: appText(13, c: AppColors.outline),
                    ),
                  ),
                ),
                const Icon(Icons.tune_rounded,
                    size: 17, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Menu layanan
// =============================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: appText(16, w: FontWeight.w700)),
              const SizedBox(height: 4),
              // garis aksen yang memanjang saat terlihat di layar
              _InView(
                delay: 250,
                ms: 900,
                builder: (_, a) => AnimatedBuilder(
                  animation: a,
                  builder: (_, __) => Container(
                    width: 30 * a.value,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.cyan],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (trailing != null)
            _Nudge(
              child: Text(trailing!,
                  style: appText(11, c: AppColors.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// Tujuan halaman dari tiap tile menu layanan.
enum _MenuTarget { jadwal, panduan, pengingat, rekamMedis, resep, farmasi }

class _MenuItem {
  const _MenuItem(
      this.icon, this.label, this.sub, this.c1, this.c2, this.target);
  final IconData icon;
  final String label;
  final String sub;
  final Color c1;
  final Color c2;
  final _MenuTarget target;
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.onOpen});

  final ValueChanged<_MenuTarget> onOpen;

  static const _items = <_MenuItem>[
    _MenuItem(Icons.calendar_month_rounded, 'Jadwal Dokter', 'Praktik & kuota',
        AppColors.primary, AppColors.primaryContainer, _MenuTarget.jadwal),
    _MenuItem(Icons.health_and_safety_rounded, 'Panduan Awal', 'Pertolongan 1',
        AppColors.secondary, AppColors.cyan, _MenuTarget.panduan),
    _MenuItem(Icons.alarm_rounded, 'Pengingat Obat', 'Notifikasi dosis',
        AppColors.tertiary, AppColors.tertiaryContainer, _MenuTarget.pengingat),
    _MenuItem(Icons.folder_shared_rounded, 'Rekam Medis', 'Riwayat & diagnosis',
        Color(0xFF6366F1), Color(0xFF9333EA), _MenuTarget.rekamMedis),
    _MenuItem(Icons.receipt_long_rounded, 'Resep Digital', 'E-Resep dokter',
        AppColors.primary, AppColors.cyan, _MenuTarget.resep),
    _MenuItem(Icons.medication_rounded, 'Status Farmasi', 'Penyiapan obat',
        AppColors.success, AppColors.cyan, _MenuTarget.farmasi),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.92,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < _items.length; i++)
          _ScrollReveal(
            // stagger per kolom -> efek gelombang kiri ke kanan
            delay: (i % 3) * 90,
            dy: 30,
            scaleFrom: 0.7,
            ms: 650,
            curve: Curves.easeOutBack, // sedikit memantul, terasa hidup
            child: _MenuTile(item: _items[i], index: i, onOpen: onOpen),
          ),
      ],
    );
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile(
      {required this.item, required this.index, required this.onOpen});

  final _MenuItem item;
  final int index;
  final ValueChanged<_MenuTarget> onOpen;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    return AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        decoration:
            glassDecoration(radius: 20, opacity: _down ? 0.9 : 0.65).copyWith(
          boxShadow: [
            BoxShadow(
              color: m.c1.withValues(alpha: _down ? 0.30 : 0.08),
              blurRadius: _down ? 22 : 12,
              offset: Offset(0, _down ? 8 : 4),
            ),
          ],
        ),
        // Material di dalam dekorasi agar ripple terlihat
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: m.c1.withValues(alpha: 0.14),
            highlightColor: Colors.transparent,
            onHighlightChanged: _set,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onOpen(m.target);
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ikon memantul + sedikit miring saat ditekan
                  AnimatedRotation(
                    turns: _down ? -0.025 : 0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: AnimatedScale(
                      scale: _down ? 1.14 : 1,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Float(
                        dy: 3,
                        ms: 2000 + widget.index * 260,
                        phase: (widget.index * 0.17) % 1.0,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [m.c1, m.c2],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: m.c1.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(m.icon, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(m.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appText(12, w: FontWeight.w700, h: 1.2)),
                  const SizedBox(height: 2),
                  Text(m.sub,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appText(10, c: AppColors.onSurfaceVariant)),
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
// Pengingat obat (contoh data) — ketuk kartu untuk membuka halaman lengkap
// =============================================================================
class _MedReminderCard extends StatefulWidget {
  const _MedReminderCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<_MedReminderCard> createState() => _MedReminderCardState();
}

class _MedReminderCardState extends State<_MedReminderCard> {
  Future<List<Json>>? _future;
  final _repo = ClinicRepository.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _repo.todayReminders();
  }

  String _time(dynamic value) {
    if (value == null) return '--:--';
    final t = value.toString();
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  Future<void> _toggle(Json row) async {
    final taken = row['taken'] == true;
    try {
      await _repo.setMedicationTaken(row['id'].toString(), !taken);
      if (!mounted) return;
      setState(_load);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status pengingat gagal diperbarui.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onOpen,
      child: FutureBuilder<List<Json>>(
          future: _future,
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <Json>[];
            final row = rows.isEmpty ? null : rows.first;
            final taken = row?['taken'] == true;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(16),
              decoration: glassDecoration(radius: 24, opacity: 0.65)
                  .copyWith(boxShadow: [
                BoxShadow(
                    color: (taken ? AppColors.success : AppColors.primary)
                        .withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ]),
              child: Column(children: [
                Row(children: [
                  Breathe(
                      amount: 0.1,
                      ms: 1400,
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: taken
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(16)),
                          child: Icon(
                              taken
                                  ? Icons.check_circle_rounded
                                  : Icons.medication_liquid_rounded,
                              color:
                                  taken ? AppColors.success : AppColors.primary,
                              size: 24))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('PENGINGAT OBAT BERIKUTNYA',
                            style: appText(9,
                                w: FontWeight.w700,
                                c: AppColors.primary,
                                ls: 0.8)),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Text('Memuat pengingat...',
                              style: appText(12, c: AppColors.onSurfaceVariant))
                        else if (snapshot.hasError)
                          Text('Pengingat tidak dapat dimuat',
                              style: appText(12, c: AppColors.onSurfaceVariant))
                        else if (row == null)
                          Text('Belum ada pengingat obat',
                              style: appText(12, w: FontWeight.w700))
                        else ...[
                          Text((row['medicine_name'] ?? 'Obat').toString(),
                              style: appText(14, w: FontWeight.w700)),
                          Text(
                              '${row['dose'] ?? ''} • ${row['usage_rule'] ?? ''} • ${_time(row['remind_time'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  appText(11, c: AppColors.onSurfaceVariant)),
                        ],
                      ])),
                  if (row != null) ...[
                    const SizedBox(width: 8),
                    Pressable(
                        scale: 0.9,
                        child: InkWell(
                            onTap: () => _toggle(row),
                            borderRadius: BorderRadius.circular(999),
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: taken
                                        ? AppColors.success
                                            .withValues(alpha: 0.15)
                                        : AppColors.primary),
                                child: Text(taken ? 'Diminum' : 'Minum',
                                    style: appText(11,
                                        w: FontWeight.w700,
                                        c: taken
                                            ? AppColors.success
                                            : Colors.white))))),
                  ],
                ]),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: taken ? 1 : 0.65),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                            height: 5,
                            color: AppColors.primary.withValues(alpha: 0.10),
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                                widthFactor: row == null ? 0 : v,
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: taken
                                                ? const [
                                                    AppColors.success,
                                                    AppColors.cyan
                                                  ]
                                                : const [
                                                    AppColors.primary,
                                                    AppColors.primaryContainer
                                                  ]))))))),
              ]),
            );
          }),
    );
  }
}

// =============================================================================
// Jadwal dokter hari ini (kuota & perubahan jadwal)
// =============================================================================
class _Doctor {
  const _Doctor({
    required this.initials,
    required this.name,
    required this.poli,
    required this.time,
    required this.quota,
    required this.c1,
    required this.c2,
    this.changeNote,
  });

  final String initials;
  final String name;
  final String poli;
  final String time;
  final int quota; // 0 = penuh
  final Color c1;
  final Color c2;
  final String? changeNote;
}

class _DoctorList extends StatefulWidget {
  const _DoctorList({required this.onBooking});
  final ValueChanged<int> onBooking;
  @override
  State<_DoctorList> createState() => _DoctorListState();
}

class _DoctorListState extends State<_DoctorList> {
  late Future<List<Json>> _future;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ClinicRepository.instance.styledSchedule(DateTime.now());
  }

  Color _color(dynamic value, Color fallback) {
    if (value == null) return fallback;
    final raw = value.toString().replaceFirst('#', '');
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed == null) return fallback;
    return Color(raw.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 178,
        child: FutureBuilder<List<Json>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Jadwal dokter gagal dimuat.',
                        style: appText(11, c: AppColors.onSurfaceVariant)));
              }
              final rows = snapshot.data ?? const <Json>[];
              if (rows.isEmpty) {
                return Center(
                    child: Text('Tidak ada jadwal dokter hari ini.',
                        style: appText(11, c: AppColors.onSurfaceVariant)));
              }
              final doctors = rows.map((r) {
                final name =
                    (r['doctor_name'] ?? r['full_name'] ?? 'Dokter').toString();
                final initials = (r['initials'] ??
                        name
                            .split(RegExp(r'\s+'))
                            .where((x) => x.isNotEmpty)
                            .take(2)
                            .map((x) => x[0])
                            .join())
                    .toString();
                final start = (r['start_time'] ?? '').toString();
                final finish = (r['end_time'] ?? '').toString();
                final quota = (r['remaining'] ?? 0) as num;
                final note = (r['notice'] ?? '').toString();
                final c1 = _color(r['color_primary'], AppColors.primary);
                final c2 =
                    _color(r['color_secondary'], AppColors.primaryContainer);
                return _Doctor(
                    initials: initials,
                    name: name,
                    poli: (r['polyclinic_name'] ??
                            r['specialization'] ??
                            'Poliklinik')
                        .toString(),
                    time:
                        '${start.length >= 5 ? start.substring(0, 5) : start} - ${finish.length >= 5 ? finish.substring(0, 5) : finish}',
                    quota: quota.toInt(),
                    c1: c1,
                    c2: c2,
                    changeNote: note.isEmpty ? null : note);
              }).toList();
              return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemCount: doctors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _ScrollReveal(
                      delay: i * 150,
                      dx: 60,
                      dy: 0,
                      scaleFrom: 0.92,
                      child: _DoctorCard(
                          d: doctors[i],
                          onBooking: () =>
                              widget.onBooking(i.clamp(0, 2).toInt()))));
            }),
      );
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({required this.d, required this.onBooking});

  final _Doctor d;
  final VoidCallback onBooking;

  @override
  Widget build(BuildContext context) {
    final full = d.quota == 0;
    final low = !full && d.quota <= 2;
    final quotaColor =
        full ? AppColors.error : (low ? AppColors.warning : AppColors.success);

    final quotaIcon = Icon(Icons.groups_rounded, size: 15, color: quotaColor);

    return Container(
      width: 252,
      padding: const EdgeInsets.all(14),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: [d.c1, d.c2]),
                      boxShadow: [
                        BoxShadow(
                          color: d.c1.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(d.initials,
                        style:
                            appText(16, w: FontWeight.w700, c: Colors.white)),
                  ),
                  // Titik status: hijau berdenyut = praktik / abu = penuh
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: full
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle),
                            )
                          : const PulseDot(size: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: d.c1.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(d.poli,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(10, w: FontWeight.w700, c: d.c1)),
                    ),
                    const SizedBox(height: 4),
                    Text(d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(13, w: FontWeight.w700)),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 12, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(d.time,
                            style: appText(11, c: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d.changeNote != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Breathe(
                    amount: 0.3,
                    ms: 900,
                    child: Icon(Icons.update_rounded,
                        size: 13, color: AppColors.warning),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(d.changeNote!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(10,
                            w: FontWeight.w600, c: AppColors.warning)),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (low)
                    Breathe(amount: 0.3, ms: 800, child: quotaIcon)
                  else
                    quotaIcon,
                  const SizedBox(width: 4),
                  Text(full ? 'Kuota penuh' : 'Sisa kuota ${d.quota}',
                      style: appText(11, w: FontWeight.w700, c: quotaColor)),
                ],
              ),
              Pressable(
                enabled: !full,
                scale: 0.9,
                child: InkWell(
                  onTap: full ? null : onBooking,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: full
                          ? null
                          : const LinearGradient(colors: [
                              AppColors.primary,
                              AppColors.primaryContainer
                            ]),
                      color: full ? Colors.grey.shade300 : null,
                    ),
                    child: Text('Booking',
                        style: appText(11,
                            w: FontWeight.w700,
                            c: full ? Colors.grey.shade600 : Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Panduan penanganan awal + disclaimer
// =============================================================================
class _FirstAidCard extends StatefulWidget {
  const _FirstAidCard({required this.onOpen});
  final VoidCallback onOpen;
  @override
  State<_FirstAidCard> createState() => _FirstAidCardState();
}

class _FirstAidCardState extends State<_FirstAidCard> {
  late Future<List<Json>> _future;
  @override
  void initState() {
    super.initState();
    _future = ClinicRepository.instance.firstAidTopics();
  }

  Widget _chip(String label, Color color, int i) => Reveal(
        delay: 250 + i * 120,
        dy: 8,
        scaleFrom: 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: appText(10, w: FontWeight.w700, c: color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: glassDecoration(radius: 24, opacity: 0.65),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Breathe(
                    amount: 0.12,
                    ms: 1200,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded,
                          color: AppColors.error, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Panduan Penanganan Awal',
                            style: appText(14, w: FontWeight.w700)),
                        Text('Pertolongan pertama & tingkat urgensi gejala',
                            style: appText(11, c: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const _Nudge(
                    dx: 4,
                    child: Icon(Icons.chevron_right_rounded,
                        color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Json>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 8);
                  }
                  final topics = snapshot.data ?? const <Json>[];
                  if (topics.isEmpty) {
                    return Text('Belum ada panduan yang tersedia.',
                        style: appText(10.5, c: AppColors.onSurfaceVariant));
                  }
                  const colors = [
                    AppColors.success,
                    AppColors.warning,
                    AppColors.error
                  ];
                  final labels = <String>[];
                  for (final topic in topics) {
                    final urgency = (topic['urgency'] ?? '')
                        .toString()
                        .replaceAll('_', ' ');
                    if (urgency.isNotEmpty && !labels.contains(urgency)) {
                      labels.add(urgency);
                    }
                    if (labels.length == 3) break;
                  }
                  return Wrap(spacing: 6, children: [
                    for (var i = 0; i < labels.length; i++)
                      _chip(labels[i], colors[i], i)
                  ]);
                },
              ),
              const SizedBox(height: 10),
              Text(
                'Informasi ini bersifat edukatif dan bukan pengganti diagnosis '
                'atau konsultasi tenaga medis. Untuk kondisi darurat, segera '
                'cari pertolongan medis.',
                style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
