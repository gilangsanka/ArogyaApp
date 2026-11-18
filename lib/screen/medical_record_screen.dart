import 'package:flutter/material.dart';

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';

class _Visit {
  const _Visit({
    required this.date,
    required this.poli,
    required this.doctor,
    required this.diagnosis,
    required this.complaint,
    required this.action,
    required this.vitals,
    required this.color,
  });

  factory _Visit.fromJson(Json j) {
    final poliMap = j['polyclinics'] as Map?;
    final docMap = j['doctors'] as Map?;
    return _Visit(
      date: _fmtDate(j['visit_date']),
      poli: (poliMap?['name'] ?? '-').toString(),
      doctor: (docMap?['full_name'] ?? '-').toString(),
      diagnosis: _orDash(j['diagnosis']),
      complaint: _orDash(j['complaint']),
      action: _orDash(j['action_taken']),
      vitals: _vitals(j),
      color: _parseColor(poliMap?['color_primary']) ?? AppColors.primary,
    );
  }

  final String date;
  final String poli;
  final String doctor;
  final String diagnosis;
  final String complaint;
  final String action;
  final String vitals;
  final Color color;
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

/// 'YYYY-MM-DD' -> '16 Nov 2026'.
String _fmtDate(Object? v) {
  final d = DateTime.tryParse(v?.toString() ?? '');
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// 37.8 -> '37,8'; 65.0 -> '65'.
String _num(Object? v) {
  final n = num.tryParse(v?.toString() ?? '');
  if (n == null) return '';
  final s = n == n.roundToDouble() ? n.round().toString() : n.toString();
  return s.replaceAll('.', ',');
}

String _vitals(Json j) {
  final parts = <String>[];
  if (j['bp_systolic'] != null && j['bp_diastolic'] != null) {
    parts.add('TD ${_num(j['bp_systolic'])}/${_num(j['bp_diastolic'])}');
  }
  if (_num(j['temperature_c']).isNotEmpty) {
    parts.add('Suhu ${_num(j['temperature_c'])} °C');
  }
  if (_num(j['pulse_bpm']).isNotEmpty) {
    parts.add('Nadi ${_num(j['pulse_bpm'])}x/mnt');
  }
  if (_num(j['weight_kg']).isNotEmpty) {
    parts.add('BB ${_num(j['weight_kg'])} kg');
  }
  if (_num(j['height_cm']).isNotEmpty) {
    parts.add('TB ${_num(j['height_cm'])} cm');
  }
  return parts.isEmpty ? '-' : parts.join(' • ');
}

/// Mengubah '#RRGGBB' / 'RRGGBB' / '#AARRGGBB' menjadi Color.
Color? _parseColor(Object? v) {
  var h = v?.toString().trim().replaceAll('#', '') ?? '';
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final n = int.tryParse(h, radix: 16);
  return n == null ? null : Color(n);
}

class _RecordData {
  const _RecordData({
    required this.summary,
    required this.allergies,
    required this.visits,
  });

  final Json summary;
  final List<String> allergies;
  final List<_Visit> visits;
}

/// Rekam medis pasien, diambil dari Supabase.
class MedicalRecordScreen extends StatefulWidget {
  const MedicalRecordScreen({super.key});

  @override
  State<MedicalRecordScreen> createState() => _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends State<MedicalRecordScreen> {
  late Future<_RecordData> _future;
  int _f = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_RecordData> _loadData() async {
    final repo = ClinicRepository.instance;
    final results = await Future.wait<dynamic>([
      repo.patientSummary(),
      repo.allergies(),
      repo.medicalRecords(),
    ]);
    return _RecordData(
      summary: results[0] as Json,
      allergies: results[1] as List<String>,
      visits: (results[2] as List<Json>)
          .map(_Visit.fromJson)
          .toList(growable: false),
    );
  }

  void _reload() => setState(() => _future = _loadData());

  Widget _stat(IconData icon, String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: Column(
          children: [
            Breathe(
              amount: 0.12,
              ms: 1800,
              child: Icon(icon, size: 20, color: c),
            ),
            const SizedBox(height: 4),
            Text(value,
                textAlign: TextAlign.center,
                style: appText(13, w: FontWeight.w700)),
            Text(label,
                textAlign: TextAlign.center,
                style: appText(10, c: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _content(_RecordData d) {
    final visits = d.visits;
    // Filter poli mengikuti poli yang ada pada riwayat pasien.
    final filters = [
      'Semua',
      ...{for (final v in visits) v.poli},
    ];
    final f = _f < filters.length ? _f : 0;
    final list =
        f == 0 ? visits : visits.where((v) => v.poli == filters[f]).toList();

    final sm = d.summary;
    final h = _num(sm['height_cm']);
    final w = _num(sm['weight_kg']);
    final tbbb = (h.isEmpty && w.isEmpty)
        ? '-'
        : '${h.isEmpty ? '-' : h} / ${w.isEmpty ? '-' : w}';
    final blood = _orDash(sm['blood_type']);
    final rm = _orDash(sm['medical_record_no']);
    final verified = sm['is_verified'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('No. RM  $rm', style: appText(12, w: FontWeight.w700)),
                  const Spacer(),
                  if (verified)
                    const StatusPill('Terverifikasi', AppColors.success,
                        icon: Icons.verified_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _stat(Icons.bloodtype_rounded, 'Gol. darah', blood,
                      AppColors.error),
                  const SizedBox(width: 8),
                  _stat(
                      Icons.height_rounded, 'TB / BB', tbbb, AppColors.primary),
                  const SizedBox(width: 8),
                  _stat(
                      Icons.warning_amber_rounded,
                      'Alergi',
                      d.allergies.isEmpty
                          ? 'Tidak ada'
                          : '${d.allergies.length} jenis',
                      AppColors.warning),
                ],
              ),
              if (d.allergies.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in d.allergies)
                      StatusPill('Alergi: $a', AppColors.warning),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Riwayat Kunjungan'),
        const SizedBox(height: 12),
        ChipBar(
          options: filters,
          selected: f,
          onChanged: (i) => setState(() => _f = i),
        ),
        const SizedBox(height: 16),
        if (visits.isEmpty)
          const EmptyCard(
              icon: Icons.folder_off_rounded,
              text: 'Belum ada riwayat kunjungan.')
        else if (list.isEmpty)
          const EmptyCard(
              icon: Icons.folder_off_rounded,
              text: 'Belum ada riwayat untuk poli ini.')
        else
          for (final v in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _VisitCard(v: v),
            ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Data rekam medis bersifat rahasia dan hanya dapat dilihat oleh '
            'Anda dan tenaga medis yang menangani.',
            style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Rekam Medis',
      subtitle: 'Riwayat & diagnosis',
      icon: Icons.folder_shared_rounded,
      accent: const Color(0xFF6366F1),
      accent2: const Color(0xFF9333EA),
      children: [
        FutureBuilder<_RecordData>(
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
                        'Rekam medis belum dapat dimuat.\nPeriksa koneksi internet, lalu coba lagi.',
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

class _VisitCard extends StatefulWidget {
  const _VisitCard({required this.v});

  final _Visit v;

  @override
  State<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<_VisitCard> {
  bool _open = false;

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: appText(10,
                          w: FontWeight.w700, c: AppColors.onSurfaceVariant)),
                  Text(value, style: appText(12, h: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    return GlassCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 44,
                decoration: BoxDecoration(
                  color: v.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(v.date,
                            style: appText(11,
                                w: FontWeight.w700,
                                c: AppColors.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        StatusPill(v.poli, v.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(v.diagnosis,
                        style: appText(13.5, w: FontWeight.w700, h: 1.3)),
                    Text(v.doctor,
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more_rounded,
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, color: Colors.white),
                        const SizedBox(height: 10),
                        _row(Icons.chat_bubble_outline_rounded, 'KELUHAN',
                            v.complaint),
                        _row(Icons.monitor_heart_outlined, 'TANDA VITAL',
                            v.vitals),
                        _row(Icons.medical_services_outlined, 'TINDAKAN',
                            v.action),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
