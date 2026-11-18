import 'package:flutter/material.dart';

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';
import 'e_prescription_screen.dart';
import 'med_reminder_screen.dart';
import 'pharmacy_status_screen.dart';

enum _Kind { antrean, obat, farmasi, resep }

extension _KindX on _Kind {
  String get label => switch (this) {
        _Kind.antrean => 'Antrean',
        _Kind.obat => 'Obat',
        _Kind.farmasi => 'Farmasi',
        _Kind.resep => 'Resep',
      };

  IconData get icon => switch (this) {
        _Kind.antrean => Icons.confirmation_number_rounded,
        _Kind.obat => Icons.alarm_rounded,
        _Kind.farmasi => Icons.medication_rounded,
        _Kind.resep => Icons.receipt_long_rounded,
      };
}

class _Notif {
  const _Notif({
    required this.kind,
    required this.title,
    required this.body,
    required this.color,
    required this.priority,
    this.tag,
    this.target,
  });

  final _Kind kind;
  final String title;
  final String body;
  final Color color;

  /// Semakin kecil semakin atas.
  final int priority;

  /// Label kecil di kanan atas (mis. "Terlambat").
  final String? tag;

  /// Halaman yang dibuka saat kartu diketuk (null = tidak ada).
  final Widget Function()? target;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 'YYYY-MM-DD' atau timestamp -> '16 Nov 2026' (WIB).
String _fmtDate(Object? v) {
  final raw = v?.toString() ?? '';
  var d = DateTime.tryParse(raw);
  if (d == null) return '-';
  if (raw.length > 10) d = d.toUtc().add(const Duration(hours: 7));
  return '${_two(d.day)} ${_months[d.month - 1]} ${d.year}';
}

/// 'HH:mm:ss' -> 'HH.mm'.
String _fmtHm(Object? v) {
  final p = (v?.toString() ?? '').split(':');
  if (p.length < 2) return '-';
  return '${p[0].padLeft(2, '0')}.${p[1]}';
}

String _s(Object? v, [String fallback = '-']) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

/// Notifikasi pasien. Disusun dari data di Supabase: antrean/booking aktif,
/// pengingat minum obat hari ini, status pesanan farmasi, dan resep aktif.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const _filters = ['Semua', 'Antrean', 'Obat', 'Farmasi', 'Resep'];

  final _repo = ClinicRepository.instance;
  late Future<List<_Notif>> _future;
  int _f = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<List<_Notif>> _load() async {
    // Tiap sumber dimuat terpisah: satu yang gagal tidak menggagalkan semua.
    final sources = <Future<List<_Notif>>>[
      _appointments(),
      _reminders(),
      _pharmacy(),
      _prescriptions(),
    ];
    var failed = 0;
    final out = <_Notif>[];
    for (final src in sources) {
      try {
        out.addAll(await src);
      } catch (_) {
        failed++;
      }
    }
    if (failed == sources.length) throw StateError('Semua sumber gagal');
    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out;
  }

  // ------------------------------------------------------------ Antrean
  Future<List<_Notif>> _appointments() async {
    final rows = await _repo.activeAppointments();
    return [
      for (final a in rows)
        _Notif(
          kind: _Kind.antrean,
          title: switch (a['status']) {
            'checked_in' => 'Check-in berhasil',
            'in_exam' => 'Giliran Anda sedang diperiksa',
            'pharmacy' => 'Menunggu obat di farmasi',
            _ => 'Booking terkonfirmasi',
          },
          body: 'Antrean ${_s(a['queue_label'])} • '
              '${_s((a['polyclinics'] as Map?)?['name'])} • '
              '${_fmtDate(a['appt_date'])}, ${_fmtHm(a['appt_time'])} WIB\n'
              '${_s((a['doctors'] as Map?)?['full_name'])}',
          color: AppColors.primary,
          priority: 20,
          tag: a['status'] == 'in_exam' ? 'Sekarang' : null,
        ),
    ];
  }

  // ------------------------------------------------------- Pengingat obat
  Future<List<_Notif>> _reminders() async {
    final rows = await _repo.todayReminders();
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final nowMin = now.hour * 60 + now.minute;
    final out = <_Notif>[];
    for (final r in rows) {
      if (r['is_active'] != true || r['taken'] == true) continue;
      final p = _s(r['remind_time'], '00:00').split(':');
      final min = (int.tryParse(p[0]) ?? 0) * 60 +
          (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
      final late = min < nowMin;
      out.add(_Notif(
        kind: _Kind.obat,
        title:
            late ? 'Jadwal minum obat terlewat' : 'Waktunya minum obat nanti',
        body: '${_s(r['medicine_name'])} • ${_s(r['dose'])} • '
            '${_s(r['usage_rule'])}\nPukul ${_fmtHm(r['remind_time'])} WIB',
        color: late ? AppColors.warning : AppColors.tertiary,
        priority: late ? 10 : 30 + min ~/ 60,
        tag: late ? 'Terlambat' : null,
        target: () => const MedReminderScreen(),
      ));
    }
    return out;
  }

  // -------------------------------------------------------------- Farmasi
  Future<List<_Notif>> _pharmacy() async {
    final o = await _repo.pharmacyOrder();
    if (o == null) return [];
    final st = _s(o['status'], '').toLowerCase();
    final ready =
        st.contains('ready') || st.contains('siap') || st.contains('picked');
    final code = _s((o['prescriptions'] as Map?)?['code'], '');
    final eta = o['eta_minutes'];
    return [
      _Notif(
        kind: _Kind.farmasi,
        title: ready ? 'Obat siap diambil' : 'Obat sedang disiapkan',
        body: ready
            ? 'Tunjukkan nomor ${_s(o['queue_label'])} di loket farmasi.'
            : 'Nomor antrean farmasi ${_s(o['queue_label'])}'
                '${eta == null ? '' : ' • estimasi ~$eta mnt'}.',
        color: ready ? AppColors.success : AppColors.primary,
        priority: ready ? 5 : 15,
        tag: ready ? 'Siap' : null,
        target: () => PharmacyStatusScreen(rxCode: code.isEmpty ? null : code),
      ),
    ];
  }

  // ---------------------------------------------------------------- Resep
  Future<List<_Notif>> _prescriptions() async {
    final rows = await _repo.prescriptions();
    return [
      for (final r in rows.where((r) => r['status'] == 'active').take(3))
        _Notif(
          kind: _Kind.resep,
          title: 'Resep digital aktif',
          body:
              '${_s(r['code'])} dari ${_s((r['doctors'] as Map?)?['full_name'])}'
              '\nDiterbitkan ${_fmtDate(r['issued_at'])}',
          color: AppColors.cyan,
          priority: 40,
          target: () => const EPrescriptionScreen(),
        ),
    ];
  }

  // ------------------------------------------------------------------ UI
  Widget _card(_Notif n) {
    final card = GlassCard(
      onTap: n.target == null ? null : () => pushPage(context, n.target!()),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: n.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(n.kind.icon, size: 21, color: n.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: appText(13.5, w: FontWeight.w700, h: 1.3)),
                    ),
                    if (n.tag != null) ...[
                      const SizedBox(width: 8),
                      StatusPill(n.tag!, n.color),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(n.body,
                    style:
                        appText(11.5, c: AppColors.onSurfaceVariant, h: 1.4)),
              ],
            ),
          ),
          if (n.target != null)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 10),
              child: Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: card);
  }

  Widget _content(List<_Notif> all) {
    final kind = _f == 0 ? null : _Kind.values[_f - 1];
    final list = kind == null ? all : all.where((n) => n.kind == kind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipBar(
          options: _filters,
          selected: _f,
          onChanged: (i) => setState(() => _f = i),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyCard(
            icon: Icons.notifications_off_outlined,
            text: all.isEmpty
                ? 'Belum ada notifikasi.\nPemberitahuan antrean, obat, dan resep akan muncul di sini.'
                : 'Tidak ada notifikasi ${kind!.label.toLowerCase()}.',
          )
        else
          for (final n in list) _card(n),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Notifikasi diperbarui setiap halaman ini dibuka. Ketuk kartu '
            'untuk melihat detailnya.',
            style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Notifikasi',
      subtitle: 'Pemberitahuan terbaru',
      icon: Icons.notifications_rounded,
      accent: AppColors.primary,
      accent2: AppColors.cyan,
      children: [
        FutureBuilder<List<_Notif>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Column(
                children: [
                  const EmptyCard(
                    icon: Icons.wifi_off_rounded,
                    text:
                        'Notifikasi belum dapat dimuat.\nPeriksa koneksi internet, lalu coba lagi.',
                  ),
                  TextButton(
                      onPressed: _reload, child: const Text('Coba lagi')),
                ],
              );
            }
            return _content(snapshot.data!);
          },
        ),
      ],
    );
  }
}
