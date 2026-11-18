import 'package:flutter/material.dart';

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';

class _Dr {
  const _Dr({
    required this.id,
    required this.polyId,
    required this.initials,
    required this.name,
    required this.poli,
    required this.time,
    required this.quota,
    required this.c1,
    required this.c2,
    required this.poliIdx,
    required this.docIdx,
    this.note,
  });

  final String id;
  final String polyId;
  final String initials;
  final String name;
  final String poli;
  final String time;
  final int? quota;
  final Color c1;
  final Color c2;
  final int poliIdx;
  final int docIdx;
  final String? note;
}

/// Jadwal praktik dokter yang diambil langsung dari Supabase.
///
/// Gunakan [onBookDoctor] bila halaman Booking menerima ID dokter dan ID poli.
/// [onBook] tetap tersedia agar kompatibel dengan navigasi lama berbasis indeks.
class DoctorScheduleScreen extends StatefulWidget {
  const DoctorScheduleScreen({
    super.key,
    this.onBook,
    this.onBookDoctor,
  });

  final void Function(int poli, int doc)? onBook;
  final void Function(String doctorId, String polyclinicId)? onBookDoctor;

  @override
  State<DoctorScheduleScreen> createState() => _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends State<DoctorScheduleScreen> {
  static const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _fullDay = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];
  static const _months = [
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
    'Des'
  ];

  late final List<DateTime> _dates = List.generate(
    7,
    (i) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return today.add(Duration(days: i));
    },
  );

  int _day = 0;
  int _poli = 0;
  bool _loading = true;
  String? _error;
  List<Json> _polyclinics = [];
  List<_Dr> _doctors = [];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  dynamic _first(Json row, List<String> keys) {
    for (final key in keys) {
      if (row[key] != null) return row[key];
    }
    return null;
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Color _color(dynamic value, Color fallback) {
    if (value == null) return fallback;
    var raw = value.toString().trim().replaceAll('#', '');
    if (raw.startsWith('0x')) raw = raw.substring(2);
    if (raw.length == 6) raw = 'FF$raw';
    final parsed = int.tryParse(raw, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  String _timeText(Json row) {
    final direct = _first(
        row, ['practice_time', 'time_range', 'schedule_time', 'jam_praktik']);
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }
    final start =
        _first(row, ['start_time', 'practice_start', 'start_at', 'jam_mulai']);
    final end =
        _first(row, ['end_time', 'practice_end', 'end_at', 'jam_selesai']);
    if (start != null && end != null) {
      return '${_shortTime(start)} - ${_shortTime(end)}';
    }
    return 'Jadwal tersedia';
  }

  String _shortTime(dynamic value) {
    final text = value.toString();
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  Future<void> _loadSchedule() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ClinicRepository.instance.polyclinics(),
        ClinicRepository.instance.styledSchedule(_dates[_day]),
      ]);
      final polis = results[0] as List<Json>;
      final rows = results[1] as List<Json>;

      final poliIndexById = <String, int>{
        for (var i = 0; i < polis.length; i++) _str(polis[i]['id']): i,
      };
      final doctorIndexByPoly = <String, int>{};
      final parsed = <_Dr>[];

      for (final row in rows) {
        final polyId = _str(row['polyclinic_id']);
        final doctorId = _str(row['doctor_id']);
        if (polyId.isEmpty || doctorId.isEmpty) continue;

        final poly = polis.cast<Json?>().firstWhere(
              (p) => p != null && _str(p['id']) == polyId,
              orElse: () => null,
            );
        if (poly == null) continue;

        final polyName = _str(
          _first(row, ['polyclinic_name', 'poli_name', 'polyclinic']),
          _str(_first(poly, ['name', 'full_name']), 'Poli'),
        );
        final doctorName = _str(
          _first(row, ['doctor_name', 'full_name', 'name']),
          'Dokter',
        );
        final idx = doctorIndexByPoly[polyId] ?? 0;
        doctorIndexByPoly[polyId] = idx + 1;

        final remaining = _intValue(_first(row, [
          'remaining_quota',
          'quota_remaining',
          'remaining_slots',
          'available_quota',
          'sisa_kuota',
          'quota'
        ]));
        final note = _str(_first(row,
            ['change_note', 'schedule_note', 'note', 'catatan_perubahan']));

        parsed.add(_Dr(
          id: doctorId,
          polyId: polyId,
          initials: doctorName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join(),
          name: doctorName,
          poli: polyName,
          time: _timeText(row),
          quota: remaining,
          c1: _color(row['color_primary'], AppColors.primary),
          c2: _color(row['color_secondary'], AppColors.primaryContainer),
          poliIdx: poliIndexById[polyId] ?? 0,
          docIdx: idx,
          note: note.isEmpty ? null : note,
        ));
      }

      if (!mounted) return;
      setState(() {
        _polyclinics = polis;
        _doctors = parsed;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<String> get _poliFilters => [
        'Semua',
        ..._polyclinics.map(
          (p) => _str(_first(p, ['name', 'full_name']), 'Poli'),
        ),
      ];

  List<_Dr> get _filteredDoctors {
    final date = _dates[_day];
    final selectedName = _poli == 0 ? null : _poliFilters[_poli];
    return _doctors.where((d) {
      // RPC get_doctor_schedule sudah menerima tanggal yang dipilih.
      // Filter poli dilakukan di sisi tampilan.
      return selectedName == null || d.poli == selectedName;
    }).toList();
  }

  void _book(_Dr doctor) {
    if (widget.onBookDoctor != null) {
      Navigator.of(context).pop();
      widget.onBookDoctor!(doctor.id, doctor.polyId);
      return;
    }
    if (widget.onBook != null) {
      Navigator.of(context).pop();
      widget.onBook!(doctor.poliIdx, doctor.docIdx);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Navigasi halaman Booking belum dihubungkan.')),
    );
  }

  Widget _dateStrip() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _dates[i];
          final on = i == _day;
          return GestureDetector(
            onTap: () {
              setState(() => _day = i);
              _loadSchedule();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryContainer],
                      )
                    : null,
                color: on ? null : Colors.white.withValues(alpha: 0.7),
                border: Border.all(
                  color: on ? AppColors.primary : Colors.white,
                  width: 1,
                ),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0 ? 'Hari ini' : _dayNames[d.weekday - 1],
                    style: appText(
                      10,
                      w: FontWeight.w600,
                      c: on ? Colors.white : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    style: appText(
                      18,
                      w: FontWeight.w700,
                      c: on ? Colors.white : const Color(0xFF1B1B1F),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(_Dr d) {
    final full = d.quota != null && d.quota == 0;
    final low = d.quota != null && !full && d.quota! <= 2;
    final qc =
        full ? AppColors.error : (low ? AppColors.warning : AppColors.success);
    final qText = d.quota == null
        ? 'Kuota tersedia'
        : (full ? 'Kuota penuh' : 'Sisa kuota ${d.quota}');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [d.c1, d.c2]),
                  boxShadow: [
                    BoxShadow(
                      color: d.c1.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  d.initials,
                  style: appText(17, w: FontWeight.w700, c: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(d.poli, d.c1),
                    const SizedBox(height: 4),
                    Text(d.name, style: appText(14, w: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          d.time,
                          style: appText(12, c: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (d.note != null && _day == 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Breathe(
                    amount: 0.3,
                    ms: 900,
                    child: Icon(
                      Icons.update_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      d.note!,
                      style: appText(
                        11,
                        w: FontWeight.w600,
                        c: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_rounded, size: 16, color: qc),
                  const SizedBox(width: 5),
                  Text(qText, style: appText(12, w: FontWeight.w700, c: qc)),
                ],
              ),
              Pressable(
                enabled: !full,
                scale: 0.9,
                child: InkWell(
                  onTap: full ? null : () => _book(d),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: full
                          ? null
                          : const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryContainer
                              ],
                            ),
                      color: full ? Colors.grey.shade300 : null,
                    ),
                    child: Text(
                      'Booking',
                      style: appText(
                        12,
                        w: FontWeight.w700,
                        c: full ? Colors.grey.shade600 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = _dates[_day];

    return SubPage(
      title: 'Jadwal Dokter',
      subtitle: 'Praktik & kuota',
      icon: Icons.calendar_month_rounded,
      children: [
        _dateStrip(),
        if (_poliFilters.length > 1)
          ChipBar(
            options: _poliFilters,
            selected: _poli,
            onChanged: (i) => setState(() => _poli = i),
          ),
        SectionLabel(
          '${_fullDay[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}',
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          GlassCard(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 34, color: AppColors.error),
                const SizedBox(height: 8),
                Text(
                  'Jadwal dokter gagal dimuat.',
                  style: appText(14, w: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: appText(11, c: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _loadSchedule,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          )
        else if (_filteredDoctors.isEmpty)
          const EmptyCard(
            icon: Icons.event_busy_rounded,
            text: 'Tidak ada dokter yang praktik pada hari\n'
                'dan filter yang dipilih.',
          )
        else
          for (final doctor in _filteredDoctors) _card(doctor),
      ],
    );
  }
}
