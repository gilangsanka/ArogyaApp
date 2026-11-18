import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';
import 'pharmacy_status_screen.dart';

class _RxItem {
  const _RxItem(this.name, this.rule, this.qty);

  factory _RxItem.fromJson(Json j) {
    String clean(Object? v) => v?.toString().trim() ?? '';
    final rule = [clean(j['dosage']), clean(j['instructions'])]
        .where((e) => e.isNotEmpty)
        .join(' • ');
    final q = j['quantity'];
    final qty = q == null
        ? ''
        : [
            (q is num && q == q.roundToDouble()) ? q.round().toString() : '$q',
            clean(j['unit']),
          ].where((e) => e.isNotEmpty).join(' ');
    return _RxItem(_orDash(j['medicine_name']), rule.isEmpty ? '-' : rule, qty);
  }

  final String name;
  final String rule;
  final String qty;
}

class _Rx {
  const _Rx({
    required this.code,
    required this.date,
    required this.doctor,
    required this.poli,
    required this.active,
    required this.items,
  });

  factory _Rx.fromJson(Json j) {
    final items =
        List<Json>.from((j['prescription_items'] as List?) ?? const [])
          ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
              .compareTo((b['sort_order'] as num?) ?? 0));
    return _Rx(
      code: (j['code'] ?? '-').toString(),
      date: _fmtDate(j['issued_at']),
      doctor: _orDash((j['doctors'] as Map?)?['full_name']),
      poli: _orDash((j['polyclinics'] as Map?)?['name']),
      active: j['status'] == 'active',
      items: items.map(_RxItem.fromJson).toList(growable: false),
    );
  }

  final String code;
  final String date;
  final String doctor;
  final String poli;
  final bool active;
  final List<_RxItem> items;
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

String _orDash(Object? v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? '-' : s;
}

/// Timestamp dari database -> '16 Nov 2026' (zona waktu WIB).
String _fmtDate(Object? v) {
  final parsed = DateTime.tryParse(v?.toString() ?? '');
  if (parsed == null) return '-';
  final d = parsed.toUtc().add(const Duration(hours: 7));
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// Resep digital, diambil dari Supabase.
class EPrescriptionScreen extends StatefulWidget {
  const EPrescriptionScreen({super.key});

  @override
  State<EPrescriptionScreen> createState() => _EPrescriptionScreenState();
}

class _EPrescriptionScreenState extends State<EPrescriptionScreen> {
  late Future<List<_Rx>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Rx>> _load() async {
    final rows = await ClinicRepository.instance.prescriptions();
    return rows.map(_Rx.fromJson).toList(growable: false);
  }

  void _reload() => setState(() => _future = _load());

  static const _tabs = ['Aktif', 'Riwayat'];
  int _tab = 0;

  Widget _content(List<_Rx> all) {
    final list = all.where((r) => r.active == (_tab == 0)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChipBar(
          options: _tabs,
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyCard(
            icon: Icons.receipt_long_outlined,
            text: _tab == 0
                ? 'Tidak ada resep aktif.\nResep baru dari dokter akan muncul di sini.'
                : 'Belum ada riwayat resep.',
          )
        else
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _RxCard(rx: r),
            ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Tunjukkan kode resep di loket farmasi atau tebus lewat aplikasi. '
            'Gunakan obat sesuai petunjuk dokter.',
            style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Resep Digital',
      subtitle: 'E-Resep dokter',
      icon: Icons.receipt_long_rounded,
      accent: AppColors.primary,
      accent2: AppColors.cyan,
      children: [
        FutureBuilder<List<_Rx>>(
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
                        'Resep belum dapat dimuat.\nPeriksa koneksi internet, lalu coba lagi.',
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

class _RxCard extends StatelessWidget {
  const _RxCard({required this.rx});

  final _Rx rx;

  @override
  Widget build(BuildContext context) {
    final c = rx.active ? AppColors.primary : AppColors.outline;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(rx.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appText(13, w: FontWeight.w700, c: c)),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Clipboard.setData(ClipboardData(text: rx.code));
                            showToast(context, 'Kode resep disalin');
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.copy_rounded,
                                size: 14, color: AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${rx.date} • ${rx.doctor}',
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              rx.active
                  ? const StatusPill('Aktif', AppColors.success,
                      icon: Icons.check_circle_rounded)
                  : const StatusPill('Selesai', AppColors.outline),
            ],
          ),
          const SizedBox(height: 4),
          StatusPill(rx.poli, AppColors.tertiary),
          const SizedBox(height: 10),
          for (final it in rx.items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        size: 19, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name, style: appText(12.5, w: FontWeight.w700)),
                        Text(it.rule,
                            style:
                                appText(10.5, c: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(it.qty,
                      style: appText(11,
                          w: FontWeight.w700, c: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          if (rx.active)
            Pressable(
              scale: 0.97,
              child: InkWell(
                onTap: () =>
                    pushPage(context, PharmacyStatusScreen(rxCode: rx.code)),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(colors: [
                      AppColors.primaryContainer,
                      AppColors.primary
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppColors.primaryContainer.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Pantau di Farmasi',
                          style: appText(12.5,
                              w: FontWeight.w700, c: Colors.white)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 17, color: Colors.white),
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
