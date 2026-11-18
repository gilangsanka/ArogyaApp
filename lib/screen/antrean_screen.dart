import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, RealtimeChannel;

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart' show ymd, wibToday;
import '../widgets/anim.dart';

// =============================================================================
// Model tiket antrean (dibuat BookingScreen setelah booking dikonfirmasi).
// =============================================================================
class QueueTicket {
  const QueueTicket({
    required this.prefix,
    required this.number,
    required this.code,
    required this.poli,
    required this.doctor,
    required this.dateText,
    required this.time,
    required this.patientType,
    required this.c1,
    required this.c2,
    required this.icon,
    this.complaint = '',
  });

  final String prefix; // A, B, C ...
  final int number;
  final String code;
  final String poli;
  final String doctor;
  final String dateText;
  final String time;
  final String patientType;
  final String complaint;
  final Color c1;
  final Color c2;
  final IconData icon;

  String get label => '$prefix-${number.toString().padLeft(3, '0')}';

  /// Contoh data untuk uji tampilan: `QueueScreen(ticket: QueueTicket.demo)`.
  static const demo = QueueTicket(
    prefix: 'B',
    number: 24,
    code: 'BK482913',
    poli: 'Poli Gigi & Mulut',
    doctor: 'drg. Rina Anggraini',
    dateText: 'Senin, 16 Nov 2026',
    time: '14:30',
    patientType: 'Pasien Umum',
    c1: AppColors.secondary,
    c2: AppColors.cyan,
    icon: Icons.mood_rounded,
  );
}

// Tahap pelayanan.
const _stageTitles = <(IconData, String, String)>[
  (Icons.how_to_reg_rounded, 'Terdaftar', 'Booking berhasil dibuat'),
  (Icons.login_rounded, 'Check-in', 'Konfirmasi kedatangan di klinik'),
  (Icons.hourglass_top_rounded, 'Menunggu', 'Antre sesuai nomor Anda'),
  (Icons.medical_services_rounded, 'Pemeriksaan', 'Masuk ruang periksa dokter'),
  (Icons.medication_rounded, 'Farmasi', 'Pengambilan obat / e-resep'),
  (Icons.task_alt_rounded, 'Selesai', 'Terima kasih, semoga lekas sehat'),
];

// -----------------------------------------------------------------------------
// Helper konversi data database -> tampilan
// -----------------------------------------------------------------------------
Color _dbColor(dynamic value, Color fallback) {
  if (value == null) return fallback;
  if (value is int) return Color(value);
  var raw = value.toString().trim().replaceAll('#', '').replaceAll('0x', '');
  if (raw.length == 6) raw = 'FF$raw';
  final parsed = int.tryParse(raw, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

IconData _poliIcon(String? key) {
  switch (key?.toLowerCase()) {
    case 'medical_services':
    case 'medical':
    case 'general':
    case 'stethoscope':
      return Icons.medical_services_rounded;
    case 'dental':
    case 'tooth':
    case 'mood':
      return Icons.mood_rounded;
    case 'child':
    case 'child_care':
      return Icons.child_care_rounded;
    case 'heart':
    case 'monitor_heart':
    case 'internal_medicine':
      return Icons.monitor_heart_rounded;
    case 'eye':
    case 'visibility':
      return Icons.visibility_rounded;
    case 'pregnant_woman':
    case 'pregnancy':
    case 'obgyn':
      return Icons.pregnant_woman_rounded;
    default:
      return Icons.local_hospital_rounded;
  }
}

String _hhmm(dynamic value) {
  final s = (value ?? '').toString();
  return s.length >= 5 ? s.substring(0, 5) : s;
}

String _fmtDate(String yyyyMMdd) {
  final d = DateTime.tryParse(yyyyMMdd);
  if (d == null) return yyyyMMdd;
  const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
}

// =============================================================================
// Halaman Antrean.
// [onNavigate]: 0 = Beranda, 1 = Booking, 2 = Antrean, 3 = Profil.
// Data antrean diambil dari database (booking aktif + papan antrean poli).
// [ticket] dipakai untuk memilih booking yang baru dibuat bila pasien
// memiliki lebih dari satu booking aktif, dan memicu muat ulang.
// =============================================================================
class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
    required this.onNavigate,
    this.ticket,
    this.onCancel,
  });

  final ValueChanged<int> onNavigate;
  final QueueTicket? ticket;
  final VoidCallback? onCancel;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  final ClinicRepository _repo = ClinicRepository.instance;
  RealtimeChannel? _channel;
  Timer? _poll;

  bool _loading = true;
  bool _fetching = false;
  bool _busy = false; // check-in / batal sedang diproses
  bool _remind = true;

  List<Json> _appts = const [];
  List<Json> _board = const [];

  // Untuk notifikasi perubahan giliran.
  String? _lastId;
  int _lastStage = 0;
  int _lastAhead = -1;

  static const _palette = <(Color, IconData)>[
    (AppColors.primary, Icons.medical_services_rounded),
    (AppColors.secondary, Icons.mood_rounded),
    (AppColors.tertiary, Icons.child_care_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _scroll.value = _ctrl.hasClients ? math.max(0.0, _ctrl.offset) : 0;
    });
    _load();
    _channel = _repo.listen('queue_screen_appts', 'appointments', _load);
    // Cadangan bila realtime belum aktif untuk tabel appointments.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  // QueueScreen hidup di IndexedStack: tiket baru datang lewat didUpdateWidget.
  @override
  void didUpdateWidget(covariant QueueScreen old) {
    super.didUpdateWidget(old);
    if (!identical(widget.ticket, old.ticket)) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    final ch = _channel;
    if (ch != null) _repo.unlisten(ch);
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- Data ----------------------------------------------------------------
  bool _reload = false;

  Future<void> _load() async {
    if (_fetching) {
      _reload = true; // ada perubahan saat memuat: ulangi setelah selesai
      return;
    }
    _fetching = true;
    List<Json>? appts;
    List<Json>? board;
    try {
      appts = await _repo.activeAppointments();
    } catch (e) {
      debugPrint('activeAppointments gagal: $e');
    }
    try {
      board = await _repo.queueBoard(wibToday());
    } catch (e) {
      debugPrint('get_queue_board gagal: $e');
    }
    _fetching = false;
    if (!mounted) return;
    final again = _reload;
    _reload = false;

    setState(() {
      if (appts != null) _appts = appts;
      if (board != null) _board = board;
      _loading = false;
    });

    // Notifikasi saat giliran mendekat / tiba.
    final a = _appt;
    final t = a == null ? null : _ticketOf(a);
    if (a == null || t == null) {
      _lastId = null;
      if (again) _load();
      return;
    }
    final c = _calc(a, t);
    String? note;
    if (_lastId == a['id']) {
      if (_lastStage < 3 && c.stage == 3) {
        HapticFeedback.heavyImpact();
        note = 'Giliran Anda! Silakan menuju ruang periksa';
      } else if (_remind && c.stage == 2 && c.ahead == 2 && _lastAhead > 2) {
        HapticFeedback.mediumImpact();
        note = 'Tinggal 2 antrean lagi sebelum giliran Anda';
      }
    }
    _lastId = a['id'] as String?;
    _lastStage = c.stage;
    _lastAhead = c.ahead;
    if (note != null) _snack(note);
    if (again) _load();
  }

  /// Booking yang ditampilkan: yang cocok dengan tiket terbaru, atau yang
  /// paling awal.
  Json? get _appt {
    if (_appts.isEmpty) return null;
    final code = widget.ticket?.code;
    if (code != null) {
      for (final a in _appts) {
        if (a['code'] == code) return a;
      }
    }
    return _appts.first;
  }

  QueueTicket? _ticketOf(Json a) {
    final poli = (a['polyclinics'] as Map?) ?? const {};
    final doc = (a['doctors'] as Map?) ?? const {};
    return QueueTicket(
      prefix: (a['queue_prefix'] ?? '').toString().trim(),
      number: (a['queue_number'] as num?)?.toInt() ?? 0,
      code: (a['code'] ?? '').toString(),
      poli: (poli['full_name'] ?? poli['name'] ?? 'Poliklinik').toString(),
      doctor: (doc['full_name'] ?? '-').toString(),
      dateText: _fmtDate((a['appt_date'] ?? '').toString()),
      time: _hhmm(a['appt_time']),
      patientType:
          a['patient_type'] == 'bpjs' ? 'BPJS Kesehatan' : 'Pasien Umum',
      complaint: (a['complaint'] ?? '').toString(),
      c1: _dbColor(poli['color_primary'], AppColors.primary),
      c2: _dbColor(poli['color_secondary'], AppColors.cyan),
      icon: _poliIcon(poli['icon_key']?.toString()),
    );
  }

  Json? _boardRow(Json a) {
    for (final r in _board) {
      if (r['polyclinic_id'] == a['polyclinic_id']) return r;
    }
    return null;
  }

  /// Tahap (1 check-in, 2 menunggu, 3 periksa, 4 farmasi), jumlah antrean di
  /// depan, nomor yang sedang dilayani, dan rata-rata menit dari database.
  ({int stage, int ahead, int current, num? avg}) _calc(Json a, QueueTicket t) {
    final isToday = (a['appt_date'] ?? '').toString() == ymd(wibToday());
    final row = isToday ? _boardRow(a) : null;
    final current = (row?['current_number'] as num?)?.toInt() ?? 0;
    final avg = row?['avg_minutes'] as num?;

    int stage;
    switch (a['status']) {
      case 'booked':
        stage = 1;
        break;
      case 'in_exam':
        stage = 3;
        break;
      case 'pharmacy':
        stage = 4;
        break;
      default: // checked_in
        stage = t.number > 0 && current >= t.number ? 3 : 2;
    }
    return (
      stage: stage,
      ahead: math.max(0, t.number - current - 1),
      current: current,
      avg: avg,
    );
  }

  // ---- Aksi ----------------------------------------------------------------
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
      ));
  }

  String _err(Object e) {
    if (e is PostgrestException) {
      final code = e.code == null ? '' : ' [${e.code}]';
      return '${e.message}$code';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _checkIn() async {
    final a = _appt;
    if (a == null || _busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await _repo.checkInAppointment(a['id'] as String);
      _snack('Check-in berhasil, silakan menunggu panggilan');
      await _load();
    } catch (e) {
      debugPrint('check_in_appointment gagal: $e');
      _snack('Check-in gagal: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final a = _appt;
    final t = a == null ? null : _ticketOf(a);
    if (a == null || t == null || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:
            Text('Batalkan booking?', style: appText(16, w: FontWeight.w700)),
        content: Text(
          'Nomor antrean ${t.label} akan dihapus dan slot dikembalikan.',
          style: appText(13, c: AppColors.onSurfaceVariant, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Kembali',
                style: appText(12,
                    w: FontWeight.w700, c: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Ya, batalkan',
                style: appText(12, w: FontWeight.w700, c: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.cancelAppointment(a['id'] as String);
      _snack('Booking dibatalkan');
      widget.onCancel?.call();
      await _load();
    } catch (e) {
      _snack('Gagal membatalkan: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final a = _appt;
    final t = a == null ? null : _ticketOf(a);
    return Stack(
      children: [
        AuroraBackground(scroll: _scroll),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Reveal(
                dy: -24,
                child: _Header(
                  scroll: _scroll,
                  live: t != null,
                  onBack: () => widget.onNavigate(0),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : (a == null || t == null)
                        ? _EmptyState(onBook: () => widget.onNavigate(1))
                        : _content(a, t),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content(Json a, QueueTicket t) {
    final c = _calc(a, t);
    final stage = c.stage;
    final ahead = c.ahead;
    final avg = c.avg;
    final eta = stage >= 3 || avg == null ? 0 : (ahead * avg).round();
    final progress = stage >= 3
        ? 1.0
        : (c.current <= 0 || t.number <= 0)
            ? 0.0
            : (c.current / t.number).clamp(0.0, 1.0).toDouble();
    final checkedIn = a['status'] != 'booked';

    return ListView(
      controller: _ctrl,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Reveal(
          delay: 60,
          dy: 20,
          child: _StatusBanner(stage: stage, ahead: ahead),
        ),
        const SizedBox(height: 14),
        Reveal(
          delay: 140,
          dy: 34,
          scaleFrom: 0.96,
          child: _ticketCard(t, stage, checkedIn),
        ),
        const SizedBox(height: 14),
        Reveal(
          delay: 260,
          dy: 26,
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.sensors_rounded,
                  label: 'Sedang dilayani',
                  value: c.current > 0
                      ? '${t.prefix}-${c.current.toString().padLeft(3, '0')}'
                      : '—',
                  color: t.c1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.groups_rounded,
                  label: 'Di depan Anda',
                  value: stage >= 3 ? '0' : '$ahead',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_rounded,
                  label: 'Estimasi tunggu',
                  value: eta == 0 ? '—' : '~$eta mnt',
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          delay: 340,
          dy: 26,
          child: _progressCard(t, progress, stage),
        ),
        const SizedBox(height: 20),
        const Reveal(
          delay: 400,
          dx: -16,
          dy: 0,
          child: _SectionTitle('Status Pelayanan'),
        ),
        const SizedBox(height: 10),
        Reveal(delay: 440, dy: 26, child: _timeline(stage)),
        const SizedBox(height: 14),
        Reveal(delay: 500, dy: 22, child: _reminderCard()),
        const SizedBox(height: 20),
        const Reveal(
          delay: 540,
          dx: -16,
          dy: 0,
          child: _SectionTitle('Antrean Poli Lain'),
        ),
        const SizedBox(height: 10),
        Reveal(delay: 580, dy: 22, child: _otherQueues()),
        const SizedBox(height: 18),
        Reveal(
          delay: 620,
          dy: 14,
          child: Center(
            child: TextButton.icon(
              onPressed: (stage >= 3 || _busy) ? null : _cancel,
              icon: Icon(Icons.close_rounded,
                  size: 16,
                  color: stage >= 3 ? AppColors.outline : AppColors.error),
              label: Text('Batalkan Booking',
                  style: appText(12,
                      w: FontWeight.w700,
                      c: stage >= 3 ? AppColors.outline : AppColors.error)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Estimasi waktu tunggu bersifat perkiraan dan dapat berubah '
            'sesuai kondisi pelayanan. Pastikan Anda berada di area klinik '
            'saat nomor Anda mendekati giliran.',
            textAlign: TextAlign.center,
            style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
          ),
        ),
      ],
    );
  }

  // ---- Kartu tiket ---------------------------------------------------------
  Widget _ticketCard(QueueTicket t, int stage, bool checkedIn) {
    const notch = SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration:
            BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
      ),
    );

    return Container(
      decoration: glassDecoration(radius: 28, opacity: 0.75).copyWith(
        boxShadow: [
          BoxShadow(
            color: t.c1.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Breathe(
                      amount: 0.1,
                      ms: 1500,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(colors: [t.c1, t.c2]),
                        ),
                        child: Icon(t.icon, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('POLIKLINIK',
                              style: appText(9,
                                  w: FontWeight.w700,
                                  c: AppColors.primary,
                                  ls: 0.8)),
                          Text(t.poli,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appText(14, w: FontWeight.w700)),
                        ],
                      ),
                    ),
                    _StatusChip(stage: stage),
                  ],
                ),
                const SizedBox(height: 16),
                Text('NOMOR ANTREAN ANDA',
                    style: appText(10,
                        w: FontWeight.w700, c: AppColors.primary, ls: 1)),
                const SizedBox(height: 2),
                FlowText(t.label,
                    style: appText(56, w: FontWeight.w800, ls: -1.5)),
                Text('Kode booking ${t.code}',
                    style: appText(11, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(
            height: 22,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: CustomPaint(painter: _DashPainter()),
                  ),
                ),
                Positioned(left: -11, top: 0, child: notch),
                Positioned(right: -11, top: 0, child: notch),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                _InfoRow(Icons.person_rounded, 'Dokter', t.doctor),
                _InfoRow(Icons.event_rounded, 'Tanggal', t.dateText),
                _InfoRow(Icons.schedule_rounded, 'Jam', '${t.time} WIB'),
                _InfoRow(Icons.badge_rounded, 'Pasien', t.patientType),
                if (t.complaint.isNotEmpty)
                  _InfoRow(Icons.edit_note_rounded, 'Keluhan', t.complaint),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: checkedIn
                      ? Container(
                          key: const ValueKey('done'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text('Sudah check-in',
                                  style: appText(12,
                                      w: FontWeight.w700,
                                      c: AppColors.success)),
                            ],
                          ),
                        )
                      : Column(
                          key: const ValueKey('todo'),
                          children: [
                            _GradButton(
                              label: 'Check-in Kedatangan',
                              icon: Icons.how_to_reg_rounded,
                              onTap: _checkIn,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lakukan check-in saat tiba di klinik agar '
                              'nomor Anda dapat dipanggil.',
                              textAlign: TextAlign.center,
                              style: appText(10.5,
                                  c: AppColors.onSurfaceVariant, h: 1.45),
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

  // ---- Progres menuju giliran ---------------------------------------------
  Widget _progressCard(QueueTicket t, double progress, int stage) {
    final label =
        stage >= 3 ? 'Giliran Anda sudah tiba' : 'Menuju giliran ${t.label}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: appText(13, w: FontWeight.w700)),
              ),
              Text('${(progress * 100).round()}%',
                  style: appText(12, w: FontWeight.w700, c: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 8,
                color: AppColors.primary.withValues(alpha: 0.10),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: stage >= 3
                            ? const [AppColors.success, AppColors.cyan]
                            : const [AppColors.primary, AppColors.cyan],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Timeline status -----------------------------------------------------
  Widget _timeline(int stage) {
    final finished = stage >= 5;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: Column(
        children: [
          for (var i = 0; i < _stageTitles.length; i++)
            _TimelineRow(
              icon: _stageTitles[i].$1,
              title: _stageTitles[i].$2,
              sub: _stageTitles[i].$3,
              done: i < stage || finished,
              active: i == stage && !finished,
              last: i == _stageTitles.length - 1,
            ),
        ],
      ),
    );
  }

  // ---- Pengingat -----------------------------------------------------------
  Widget _reminderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.notifications_active_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingatkan saya', style: appText(13, w: FontWeight.w700)),
                Text('Notifikasi saat tinggal 2 antrean lagi',
                    style: appText(11, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: _remind,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _remind = v);
            },
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            trackColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? AppColors.primary
                    : AppColors.outline.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  // ---- Antrean poli lain (dari papan antrean database) ---------------------
  Widget _otherQueues() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: _board.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Belum ada data antrean poli hari ini.',
                  style: appText(11, c: AppColors.onSurfaceVariant)),
            )
          : Column(
              children: [
                for (var i = 0; i < _board.length; i++) ...[
                  _OtherRow(
                    icon: _palette[i % _palette.length].$2,
                    name: (_board[i]['name'] ?? 'Poliklinik').toString(),
                    number: () {
                      final n =
                          (_board[i]['current_number'] as num?)?.toInt() ?? 0;
                      final p = (_board[i]['queue_prefix'] ?? '').toString();
                      return n <= 0 || p.isEmpty
                          ? '—'
                          : '$p-${n.toString().padLeft(3, '0')}';
                    }(),
                    color: _palette[i % _palette.length].$1,
                  ),
                  if (i != _board.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

// =============================================================================
// Header
// =============================================================================
class _Header extends StatelessWidget {
  const _Header(
      {required this.scroll, required this.onBack, required this.live});

  final ValueNotifier<double> scroll;
  final VoidCallback onBack;
  final bool live;

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
          Pressable(
            scale: 0.88,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Antrean ',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                    FlowText('Saya',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                  ],
                ),
                Text('Pantau giliran & status pelayanan',
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          if (live)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border:
                    Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PulseDot(size: 7),
                  const SizedBox(width: 6),
                  Text('LIVE',
                      style: appText(10,
                          w: FontWeight.w700, c: AppColors.success, ls: 0.8)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Kondisi kosong
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBook});

  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Reveal(
              dy: 20,
              scaleFrom: 0.8,
              child: Float(
                dy: 6,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.cyan]),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.confirmation_number_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Reveal(
              delay: 120,
              dy: 14,
              child: Text('Belum ada antrean aktif',
                  style: appText(18, w: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Reveal(
              delay: 200,
              dy: 12,
              child: Text(
                'Booking pemeriksaan terlebih dahulu untuk mendapatkan nomor '
                'antrean dan memantau giliran Anda secara real-time.',
                textAlign: TextAlign.center,
                style: appText(13, c: AppColors.onSurfaceVariant, h: 1.5),
              ),
            ),
            const SizedBox(height: 20),
            Reveal(
              delay: 300,
              dy: 16,
              child: SizedBox(
                width: 240,
                child: _GradButton(
                  label: 'Booking Sekarang',
                  icon: Icons.arrow_forward_rounded,
                  onTap: onBook,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Banner status
// =============================================================================
(String, String, IconData, Color) _statusInfo(int stage, int ahead) {
  switch (stage) {
    case 1:
      return (
        'Belum check-in',
        'Segera check-in saat tiba di klinik',
        Icons.how_to_reg_rounded,
        AppColors.warning
      );
    case 2:
      return (
        'Menunggu giliran',
        ahead == 0
            ? 'Anda berikutnya, bersiaplah!'
            : '$ahead antrean lagi sebelum Anda',
        Icons.hourglass_top_rounded,
        AppColors.primary
      );
    case 3:
      return (
        'Giliran Anda!',
        'Silakan menuju ruang periksa dokter',
        Icons.campaign_rounded,
        AppColors.success
      );
    case 4:
      return (
        'Menuju farmasi',
        'Ambil obat sesuai e-resep Anda',
        Icons.medication_rounded,
        AppColors.tertiary
      );
    default:
      return (
        'Pelayanan selesai',
        'Terima kasih, semoga lekas sehat',
        Icons.task_alt_rounded,
        AppColors.success
      );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.stage, required this.ahead});

  final int stage;
  final int ahead;

  @override
  Widget build(BuildContext context) {
    final (title, sub, icon, color) = _statusInfo(stage, ahead);
    final call = stage == 3;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Breathe(
            amount: call ? 0.18 : 0.08,
            ms: call ? 700 : 1400,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              layoutBuilder: (cur, prev) => Stack(
                alignment: Alignment.centerLeft,
                children: [...prev, if (cur != null) cur],
              ),
              child: Column(
                key: ValueKey('$stage-$ahead'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: appText(14, w: FontWeight.w700, c: color)),
                  Text(sub, style: appText(11, c: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.stage});

  final int stage;

  static const _labels = {
    1: 'Check-in',
    2: 'Menunggu',
    3: 'Dipanggil',
    4: 'Farmasi',
    5: 'Selesai',
  };

  @override
  Widget build(BuildContext context) {
    final (_, _, _, color) = _statusInfo(stage, 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(size: 7, color: color),
          const SizedBox(width: 6),
          Text(_labels[stage] ?? '',
              style: appText(11, w: FontWeight.w700, c: color)),
        ],
      ),
    );
  }
}

// =============================================================================
// Komponen kecil
// =============================================================================
class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.25)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 11) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 6, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => false;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(label, style: appText(11, c: AppColors.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appText(12, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: glassDecoration(radius: 20, opacity: 0.65).copyWith(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
                        .animate(anim),
                child: child,
              ),
            ),
            child: Text(value,
                key: ValueKey(value),
                maxLines: 1,
                style: appText(15, w: FontWeight.w700, c: color, ls: -0.2)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appText(9.5, c: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: appText(16, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Container(
            width: 30,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.cyan]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.done,
    required this.active,
    required this.last,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool done;
  final bool active;
  final bool last;

  @override
  Widget build(BuildContext context) {
    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer])
            : null,
        color:
            done ? null : Colors.white.withValues(alpha: active ? 0.95 : 0.6),
        border: Border.all(
          color: done || active
              ? AppColors.primary
              : AppColors.outline.withValues(alpha: 0.4),
          width: active ? 2 : 1.2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done
            ? const Icon(Icons.check_rounded,
                key: ValueKey('c'), size: 16, color: Colors.white)
            : Icon(icon,
                key: ValueKey('i$active'),
                size: 15,
                color: active ? AppColors.primary : AppColors.outline),
      ),
    );
    if (active) dot = Breathe(amount: 0.1, ms: 1100, child: dot);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: done
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: appText(13,
                        w: (done || active) ? FontWeight.w700 : FontWeight.w600,
                        c: (done || active)
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant),
                    child: Text(title),
                  ),
                  Text(sub, style: appText(11, c: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtherRow extends StatelessWidget {
  const _OtherRow({
    required this.icon,
    required this.name,
    required this.number,
    required this.color,
  });

  final IconData icon;
  final String name;
  final String number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: appText(12, w: FontWeight.w700)),
                Text('Sedang diperiksa',
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            layoutBuilder: (cur, prev) => Stack(
              alignment: Alignment.centerRight,
              children: [...prev, if (cur != null) cur],
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
            child: Text(number,
                key: ValueKey(number),
                style: appText(16, w: FontWeight.w700, c: color, ls: -0.3)),
          ),
        ],
      ),
    );
  }
}

/// Tombol gradien (selaras dengan tombol di Beranda/Booking).
class _GradButton extends StatelessWidget {
  const _GradButton(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      child: Container(
        height: 48,
        width: double.infinity,
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
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.3),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: appText(13, w: FontWeight.w700, c: Colors.white)),
                  const SizedBox(width: 6),
                  Icon(icon, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
