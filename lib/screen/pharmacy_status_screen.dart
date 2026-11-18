import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';

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

/// Timestamp dari database -> '28 Okt 2026' (zona waktu WIB).
String _fmtDate(Object? v) {
  final parsed = DateTime.tryParse(v?.toString() ?? '');
  if (parsed == null) return '-';
  final d = parsed.toUtc().add(const Duration(hours: 7));
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// Status pesanan farmasi pada database -> indeks tahapan (0..3).
/// Pencocokan memakai kata kunci agar tetap jalan walau penamaan status
/// berbeda; status yang tidak dikenal dianggap tahap pertama.
int _stepOf(Object? status) {
  final s = status?.toString().toLowerCase() ?? '';
  if (s.contains('ready') || s.contains('siap') || s.contains('picked')) {
    return 3;
  }
  if (s.contains('prepar') ||
      s.contains('process') ||
      s.contains('compound') ||
      s.contains('siapkan')) {
    return 2;
  }
  if (s.contains('verif')) return 1;
  return 0;
}

/// Status penyiapan obat di farmasi, diambil dari Supabase dan diperbarui
/// otomatis (realtime + muat ulang berkala).
/// Jika [rxCode] kosong, ditampilkan pesanan terbaru yang belum diambil.
class PharmacyStatusScreen extends StatefulWidget {
  const PharmacyStatusScreen({super.key, this.rxCode});

  final String? rxCode;

  @override
  State<PharmacyStatusScreen> createState() => _PharmacyStatusScreenState();
}

class _PharmacyStatusScreenState extends State<PharmacyStatusScreen> {
  static const _steps = <(IconData, String, String)>[
    (Icons.inbox_rounded, 'Resep diterima', 'Resep digital masuk ke farmasi'),
    (
      Icons.fact_check_rounded,
      'Verifikasi apoteker',
      'Apoteker memeriksa dosis & ketersediaan obat'
    ),
    (
      Icons.inventory_2_rounded,
      'Obat disiapkan',
      'Obat diracik, dikemas, dan diberi etiket'
    ),
    (
      Icons.shopping_bag_rounded,
      'Siap diambil',
      'Tunjukkan nomor antrean di loket farmasi'
    ),
  ];

  final _repo = ClinicRepository.instance;

  Json? _order;
  List<Json> _history = [];
  bool _loading = true;
  bool _error = false;
  Timer? _timer;
  RealtimeChannel? _channel;

  int get _step => _stepOf(_order?['status']);

  String get _queue {
    final q = _order?['queue_label']?.toString().trim() ?? '';
    return q.isEmpty ? '-' : q;
  }

  String get _rxCode =>
      ((_order?['prescriptions'] as Map?)?['code'] ?? widget.rxCode ?? '-')
          .toString();

  String get _eta {
    if (_step >= _steps.length - 1) return 'Sekarang';
    final m = _order?['eta_minutes'];
    return m == null ? '-' : '~$m mnt';
  }

  List<String> get _itemLines {
    final rx = _order?['prescriptions'] as Map?;
    final items =
        List<Json>.from((rx?['prescription_items'] as List?) ?? const [])
          ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
              .compareTo((b['sort_order'] as num?) ?? 0));
    return [
      for (final it in items)
        [
          (it['medicine_name'] ?? '-').toString(),
          [
            if (it['quantity'] != null)
              (it['quantity'] is num &&
                      it['quantity'] == (it['quantity'] as num).roundToDouble())
                  ? (it['quantity'] as num).round().toString()
                  : it['quantity'].toString(),
            (it['unit'] ?? '').toString().trim(),
          ].where((e) => e.isNotEmpty).join(' '),
        ].where((e) => e.isNotEmpty).join(' • '),
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Realtime (perlu Realtime aktif untuk tabel pharmacy_orders) + muat
    // ulang berkala sebagai cadangan.
    try {
      _channel = _repo.listen('pharmacy_status_screen', 'pharmacy_orders',
          () => _load(silent: true));
    } catch (_) {}
    _timer =
        Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  /// [silent] = muat ulang tanpa spinner (data lama tetap tampil).
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final res = await Future.wait<dynamic>([
        _repo.pharmacyOrder(rxCode: widget.rxCode),
        _repo.pharmacyHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _order = res[0] as Json?;
        _history = res[1] as List<Json>;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    final ch = _channel;
    if (ch != null) _repo.unlisten(ch);
    super.dispose();
  }

  Widget _statusCard() {
    final ready = _step == _steps.length - 1;
    final c = ready ? AppColors.success : AppColors.primary;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ready ? 'OBAT SIAP' : 'DALAM PROSES',
                  style: appText(10, w: FontWeight.w700, c: c, ls: 0.8)),
              const SizedBox(width: 6),
              if (!ready) const PulseDot(size: 7),
              const Spacer(),
              Text(_rxCode, style: appText(10, c: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nomor antrean farmasi',
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                    Text(_queue,
                        style: appText(30, w: FontWeight.w700, c: c, ls: -0.5)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Estimasi',
                        style: appText(10, c: AppColors.onSurfaceVariant)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Text(_eta,
                          key: ValueKey(_eta),
                          style: appText(14, w: FontWeight.w700, c: c)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: (_step + 1) / _steps.length),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: c,
                backgroundColor: c.withValues(alpha: 0.12),
              ),
            ),
          ),
          if (ready) ...[
            const SizedBox(height: 16),
            Pressable(
              scale: 0.97,
              child: InkWell(
                onTap: () => showToast(
                    context, 'Tunjukkan nomor $_queue di loket farmasi'),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                        colors: [AppColors.success, AppColors.cyan]),
                  ),
                  child: Text('Ambil di Loket Farmasi',
                      style:
                          appText(12.5, w: FontWeight.w700, c: Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeline() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tahapan', style: appText(14, w: FontWeight.w700)),
          const SizedBox(height: 16),
          for (var i = 0; i < _steps.length; i++) _stepRow(i),
        ],
      ),
    );
  }

  Widget _stepRow(int i) {
    final s = _steps[i];
    final done = i < _step || (_step == _steps.length - 1 && i == _step);
    final current = i == _step && !done;
    final last = i == _steps.length - 1;
    final c = done
        ? AppColors.success
        : (current ? AppColors.primary : Colors.grey.shade400);

    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || current ? c : Colors.grey.shade200,
        boxShadow: current
            ? [
                BoxShadow(
                  color: c.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(done ? Icons.check_rounded : s.$1,
          size: 18, color: done || current ? Colors.white : c),
    );
    if (current) dot = Breathe(amount: 0.12, ms: 1000, child: dot);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                dot,
                if (!last)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: done ? AppColors.success : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 22, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$2,
                      style: appText(13,
                          w: FontWeight.w700,
                          c: done || current
                              ? const Color(0xFF1B1B1F)
                              : AppColors.onSurfaceVariant)),
                  const SizedBox(height: 1),
                  Text(s.$3,
                      style:
                          appText(11, c: AppColors.onSurfaceVariant, h: 1.35)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsCard() {
    final lines = _itemLines;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Obat dalam pesanan', style: appText(14, w: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final it in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.medication_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(it, style: appText(12))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyCard(Json h) {
    final code = ((h['prescriptions'] as Map?)?['code'] ?? '-').toString();
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 20, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code, style: appText(12.5, w: FontWeight.w700)),
                Text(_fmtDate(h['picked_up_at']),
                    style: appText(11, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const StatusPill('Diambil', AppColors.success),
        ],
      ),
    );
  }

  Widget _content() {
    const gap = SizedBox(height: 20);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_order == null)
          const EmptyCard(
            icon: Icons.medication_outlined,
            text:
                'Belum ada pesanan di farmasi.\nResep yang sudah dikirim ke farmasi akan dipantau di sini.',
          )
        else ...[
          _statusCard(),
          gap,
          _timeline(),
          gap,
          _itemsCard(),
        ],
        gap,
        const SectionLabel('Riwayat Pengambilan'),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const EmptyCard(
            icon: Icons.history_rounded,
            text: 'Belum ada riwayat pengambilan.',
          )
        else
          for (final h in _history)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _historyCard(h),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Status Farmasi',
      subtitle: 'Penyiapan obat',
      icon: Icons.medication_rounded,
      accent: AppColors.success,
      accent2: AppColors.cyan,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error) ...[
          const EmptyCard(
            icon: Icons.wifi_off_rounded,
            text:
                'Status farmasi belum dapat dimuat.\nPeriksa koneksi internet, lalu coba lagi.',
          ),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ),
        ] else
          _content(),
      ],
    );
  }
}
