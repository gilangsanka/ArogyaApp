import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../theme/app_colors.dart';
import '../services/clinic_repository.dart';
import '../widgets/anim.dart';
import 'antrean_screen.dart' show QueueTicket;

// =============================================================================
// Data statis (ganti dengan data dari server)
// =============================================================================
const _hari = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _hariFull = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu'
];
const _bulan = [
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

String _fmtDate(DateTime d) =>
    '${_hariFull[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

class _Poli {
  const _Poli({
    required this.id,
    required this.fullName,
    required this.full,
    required this.sub,
    required this.icon,
    required this.prefix,
    required this.c1,
    required this.c2,
  });

  final String id;
  final String fullName;
  final String full;
  final String sub;
  final IconData icon;
  final String prefix;
  final Color c1;
  final Color c2;
}

class _Dok {
  const _Dok({
    required this.id,
    required this.initials,
    required this.name,
    required this.spesialis,
    required this.startH,
    required this.endH,
    required this.quota,
    required this.c1,
    required this.c2,
    this.scheduleLabel,
    this.note,
  });

  final String id;
  final String initials;
  final String name;
  final String spesialis;
  final int startH;
  final int endH;
  final int quota;
  final Color c1;
  final Color c2;
  final String? scheduleLabel;
  final String? note;

  String get time =>
      scheduleLabel ??
      '${startH.toString().padLeft(2, '0')}:00 - ${endH.toString().padLeft(2, '0')}:00';
}

class _Slot {
  const _Slot(this.label, this.available);
  final String label;
  final bool available;
}

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

String _timeOnly(dynamic value) {
  if (value == null) return '00:00';
  final text = value.toString();
  return text.length >= 5 ? text.substring(0, 5) : text;
}

int _hourOf(dynamic value) =>
    int.tryParse(_timeOnly(value).split(':').first) ?? 0;

// =============================================================================
// Halaman Booking.
// [onNavigate]: 0 = Beranda, 1 = Booking, 2 = Antrean, 3 = Profil.
// [onBooked]: dipanggil saat booking dikonfirmasi, membawa tiket antrean
//   yang ditampilkan di tab Antrean.
// =============================================================================
/// Pilihan awal dari luar (mis. tombol "Booking" di kartu dokter beranda).
class BookingPreset {
  const BookingPreset(this.poli, this.doc);

  final int poli; // indeks poli sesuai urutan sort_order database
  final int doc; // indeks dokter pada jadwal poli yang dipilih
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.onNavigate,
    this.preset,
    this.onBooked,
  });

  final ValueChanged<int> onNavigate;
  final BookingPreset? preset;
  final ValueChanged<QueueTicket>? onBooked;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);
  final TextEditingController _complaint = TextEditingController();

  final GlobalKey _docKey = GlobalKey();
  final GlobalKey _dateKey = GlobalKey();
  final GlobalKey _detailKey = GlobalKey();

  late final List<DateTime> _days =
      List.generate(7, (i) => DateTime.now().add(Duration(days: i)));

  final ClinicRepository _repository = ClinicRepository.instance;
  final List<_Poli> _poliList = [];
  List<_Dok> _doctors = [];
  List<_Slot> _slots = [];
  int? _poli;
  int? _doc;
  int _date = 0;
  String? _slot;
  int _type = 0; // 0 = umum, 1 = BPJS
  bool _submitting = false;
  bool _loadingPoli = true;
  bool _loadingDoctors = false;
  bool _loadingSlots = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _scroll.value = _ctrl.hasClients ? math.max(0.0, _ctrl.offset) : 0;
    });
    _date = _days.indexWhere((d) => d.weekday != 7);
    _loadPolyclinics();
  }

  // BookingScreen sudah hidup di IndexedStack, jadi preset baru datang
  // lewat didUpdateWidget, bukan initState.
  @override
  void didUpdateWidget(covariant BookingScreen old) {
    super.didUpdateWidget(old);
    if (widget.preset != null && !identical(widget.preset, old.preset)) {
      _applyPreset(widget.preset!);
    }
  }

  Future<void> _loadPolyclinics() async {
    try {
      final rows = await _repository.polyclinics();
      if (!mounted) return;
      final fallback = <Color>[
        AppColors.primary,
        AppColors.secondary,
        AppColors.tertiary,
        const Color(0xFF6366F1),
        AppColors.success,
        const Color(0xFFEC4899),
      ];
      setState(() {
        _poliList
          ..clear()
          ..addAll([
            for (var i = 0; i < rows.length; i++)
              _Poli(
                id: rows[i]['id'].toString(),
                fullName: (rows[i]['name'] ?? rows[i]['full_name'] ?? 'Poli')
                    .toString(),
                full: (rows[i]['full_name'] ?? rows[i]['name'] ?? 'Poli')
                    .toString(),
                sub: (rows[i]['description'] ?? '').toString(),
                icon: _poliIcon(rows[i]['icon_key']?.toString()),
                prefix: (rows[i]['queue_prefix'] ?? '').toString().trim(),
                c1: _dbColor(
                    rows[i]['color_primary'], fallback[i % fallback.length]),
                c2: _dbColor(rows[i]['color_secondary'],
                    fallback[(i + 1) % fallback.length]),
              ),
          ]);
        _loadingPoli = false;
      });
      if (widget.preset != null) await _applyPreset(widget.preset!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPoli = false);
      _snack('Gagal memuat poliklinik: $e');
    }
  }

  Future<void> _applyPreset(BookingPreset p) async {
    if (_poliList.isEmpty || p.poli < 0 || p.poli >= _poliList.length) return;
    setState(() {
      _poli = p.poli;
      _doc = null;
      _slot = null;
      _date = _days.indexWhere((d) => d.weekday != 7);
    });
    await _loadDoctors(presetDoctorIndex: p.doc);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _goTo(_doc != null ? _dateKey : _docKey);
    });
  }

  Future<void> _loadDoctors(
      {String? keepDoctorId, int? presetDoctorIndex}) async {
    if (_poli == null) return;
    setState(() {
      _loadingDoctors = true;
      _doctors = [];
      _doc = null;
      _slot = null;
      _slots = [];
    });
    try {
      final rows = await _repository.bookingDoctors(
        date: _days[_date],
        polyclinicId: _poliList[_poli!].id,
      );
      if (!mounted) return;
      final poli = _poliList[_poli!];
      final docs = [
        for (final row in rows)
          _Dok(
            id: row['doctor_id'].toString(),
            initials: (row['initials'] ?? '').toString().isNotEmpty
                ? row['initials'].toString()
                : _initials((row['doctor_name'] ?? 'Dokter').toString()),
            name: (row['doctor_name'] ?? 'Dokter').toString(),
            spesialis: (row['specialization'] ?? 'Dokter').toString(),
            startH: _hourOf(row['start_time']),
            endH: _hourOf(row['end_time']),
            quota: (row['remaining'] as num?)?.toInt() ?? 0,
            c1: _dbColor(row['color_primary'], poli.c1),
            c2: _dbColor(row['color_secondary'], poli.c2),
            scheduleLabel:
                '${_timeOnly(row['start_time'])} - ${_timeOnly(row['end_time'])}',
            note: row['notice']?.toString(),
          ),
      ];
      setState(() {
        _doctors = docs;
        _loadingDoctors = false;
        if (keepDoctorId != null) {
          final index = docs.indexWhere((d) => d.id == keepDoctorId);
          _doc = index >= 0 ? index : null;
        } else if (presetDoctorIndex != null &&
            presetDoctorIndex >= 0 &&
            presetDoctorIndex < docs.length &&
            docs[presetDoctorIndex].quota > 0) {
          _doc = presetDoctorIndex;
        }
      });
      if (_doc != null) await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDoctors = false);
      _snack('Gagal memuat dokter: $e');
    }
  }

  String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(drg?\.?|dr\.?)\s*', caseSensitive: false), '')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Future<void> _loadSlots() async {
    final dok = _dok;
    if (dok == null) return;
    setState(() {
      _loadingSlots = true;
      _slots = [];
    });
    try {
      final rows = await _repository.bookingSlots(
        doctorId: dok.id,
        date: _days[_date],
      );
      if (!mounted) return;
      setState(() {
        _slots = [
          for (final row in rows)
            _Slot(_timeOnly(row['slot_time']), row['is_available'] == true),
        ];
        _loadingSlots = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingSlots = false);
      _snack('Gagal memuat jam tersedia: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _complaint.dispose();
    super.dispose();
  }

  int get _step => _slot != null
      ? 3
      : _doc != null
          ? 2
          : _poli != null
              ? 1
              : 0;

  _Dok? get _dok => (_doc != null && _doc! >= 0 && _doc! < _doctors.length)
      ? _doctors[_doc!]
      : null;

  void _goTo(GlobalKey k) {
    Future.delayed(const Duration(milliseconds: 480), () {
      final c = k.currentContext;
      if (!mounted || c == null) return;
      Scrollable.ensureVisible(
        // ignore: use_build_context_synchronously
        c,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        alignment: 0.04,
      );
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ));
  }

  void _pickPoli(int i) {
    HapticFeedback.selectionClick();
    final changed = _poli != i;
    setState(() {
      _poli = i;
      if (changed) {
        _doc = null;
        _slot = null;
        _doctors = [];
        _slots = [];
      }
    });
    if (changed) _loadDoctors();
    _goTo(_docKey);
  }

  void _pickDoc(int i) {
    final d = _doctors[i];
    if (d.quota == 0) {
      HapticFeedback.lightImpact();
      _snack('Kuota ${d.name} penuh, silakan pilih dokter lain');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (_doc != i) _slot = null;
      _doc = i;
    });
    _loadSlots();
    _goTo(_dateKey);
  }

  void _pickDate(int i) {
    if (_days[i].weekday == 7) {
      _snack('Klinik tutup pada hari Minggu');
      return;
    }
    HapticFeedback.selectionClick();
    final selectedDoctorId = _dok?.id;
    setState(() {
      _date = i;
      _slot = null;
    });
    if (_poli != null) _loadDoctors(keepDoctorId: selectedDoctorId);
  }

  void _pickSlot(String s) {
    HapticFeedback.selectionClick();
    final first = _slot == null;
    setState(() => _slot = s);
    if (first) _goTo(_detailKey);
  }

  void _reset() {
    setState(() {
      _poli = null;
      _doc = null;
      _slot = null;
      _slots = [];
      _type = 0;
      _complaint.clear();
    });
    if (_ctrl.hasClients) {
      _ctrl.animateTo(0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _confirm() async {
    if (_submitting || _poli == null || _doc == null || _slot == null) return;
    final poli = _poliList[_poli!];
    final dok = _dok;
    if (dok == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);
    try {
      final booking = await _repository.createAppointment(
        doctorId: dok.id,
        date: _days[_date],
        time: _slot!,
        bpjs: _type == 1,
        complaint: _complaint.text.trim(),
      );
      if (!mounted) return;

      final queueNo = (booking['queue_number'] as num?)?.toInt();
      final prefix = (booking['queue_prefix'] ?? poli.prefix).toString().trim();
      final code = (booking['booking_code'] ?? '').toString();
      if (queueNo == null || code.isEmpty) {
        throw StateError(
            'Booking tersimpan, tetapi data nomor antrean/kode booking tidak lengkap.');
      }
      final queue = (booking['queue_label'] ??
              '$prefix-${queueNo.toString().padLeft(3, '0')}')
          .toString();
      final dateText = _fmtDate(_days[_date]);
      final time = _slot!;

      widget.onBooked?.call(QueueTicket(
        prefix: prefix,
        number: queueNo,
        code: code,
        poli: poli.full,
        doctor: dok.name,
        dateText: dateText,
        time: time,
        patientType: _type == 0 ? 'Pasien Umum' : 'BPJS Kesehatan',
        complaint: _complaint.text.trim(),
        c1: poli.c1,
        c2: poli.c2,
        icon: poli.icon,
      ));

      setState(() => _submitting = false);
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Tutup',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (ctx, _, __) => _SuccessDialog(
          queue: queue,
          code: code,
          poli: poli.full,
          doctor: dok.name,
          dateText: dateText,
          time: time,
          onQueue: () {
            Navigator.of(ctx).pop();
            _reset();
            widget.onNavigate(2);
          },
          onClose: () {
            Navigator.of(ctx).pop();
            _reset();
          },
        ),
        transitionBuilder: (ctx, a, _, child) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('Booking gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
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
                  onBack: () => widget.onNavigate(0),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    controller: _ctrl,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    children: [
                      Reveal(
                        delay: 80,
                        dy: 30,
                        scaleFrom: 0.96,
                        child: _IntroCard(step: step),
                      ),
                      const SizedBox(height: 22),

                      // ---- 1. Poli ----
                      const Reveal(
                        delay: 220,
                        dx: -16,
                        dy: 0,
                        child: _StepTitle(1, 'Pilih Poliklinik',
                            sub: 'Sesuaikan dengan keluhan Anda'),
                      ),
                      const SizedBox(height: 12),
                      _poliGrid(),

                      // ---- 2. Dokter ----
                      _Expand(
                        key: _docKey,
                        show: _poli != null,
                        child: _poli == null
                            ? const SizedBox.shrink()
                            : _doctorSection(),
                      ),

                      // ---- 3. Jadwal ----
                      _Expand(
                        key: _dateKey,
                        show: _doc != null,
                        child: _doc == null
                            ? const SizedBox.shrink()
                            : _scheduleSection(),
                      ),

                      // ---- 4. Detail & konfirmasi ----
                      _Expand(
                        key: _detailKey,
                        show: _slot != null,
                        child: _slot == null
                            ? const SizedBox.shrink()
                            : _detailSection(),
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

  // --------------------------------------------------------------------------
  Widget _poliGrid() {
    if (_loadingPoli) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_poliList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Tidak ada poliklinik tersedia saat ini.',
          style: appText(12, c: AppColors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < _poliList.length; i++)
          Reveal(
            delay: 300 + (i % 3) * 90 + (i ~/ 3) * 120,
            dy: 26,
            scaleFrom: 0.7,
            child: _PoliTile(
              p: _poliList[i],
              index: i,
              selected: _poli == i,
              onTap: () => _pickPoli(i),
            ),
          ),
      ],
    );
  }

  Widget _doctorSection() {
    final list = _doctors;
    return Column(
      key: ValueKey('doc-$_poli'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Reveal(
          dx: -16,
          dy: 0,
          child: _StepTitle(2, 'Pilih Dokter',
              sub:
                  '${list.length} dokter praktik di ${_poliList[_poli!].fullName}'),
        ),
        const SizedBox(height: 12),
        if (_loadingDoctors)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Tidak ada dokter dengan jadwal pada tanggal ini.',
                style: appText(12, c: AppColors.onSurfaceVariant)),
          )
        else
          for (var i = 0; i < list.length; i++) ...[
            Reveal(
              delay: 120 + i * 120,
              dx: 36,
              dy: 0,
              scaleFrom: 0.95,
              child: _DokCard(
                d: list[i],
                selected: _doc == i,
                onTap: () => _pickDoc(i),
              ),
            ),
            if (i != list.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _scheduleSection() {
    final dok = _dok!;
    final key = dok.id;
    final slots = _slots;
    final free = slots.where((s) => s.available).length;

    return Column(
      key: ValueKey('sch-$key'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Reveal(
          dx: -16,
          dy: 0,
          child:
              _StepTitle(3, 'Pilih Tanggal & Jam', sub: 'Praktik ${dok.time}'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(),
            itemCount: _days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Reveal(
              delay: 80 + i * 60,
              dx: 40,
              dy: 0,
              scaleFrom: 0.85,
              child: _DateChip(
                day: _days[i],
                today: i == 0,
                selected: _date == i,
                closed: _days[i].weekday == 7,
                onTap: () => _pickDate(i),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(radius: 24, opacity: 0.65),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_fmtDate(_days[_date]),
                        style: appText(12, w: FontWeight.w700)),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      free == 0 ? 'Slot penuh' : '$free slot tersedia',
                      key: ValueKey(free),
                      style: appText(11,
                          w: FontWeight.w700,
                          c: free == 0 ? AppColors.error : AppColors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingSlots)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (slots.isEmpty)
                Text('Tidak ada slot jadwal untuk tanggal ini.',
                    style: appText(11, c: AppColors.onSurfaceVariant))
              else
                Wrap(
                  key: ValueKey('slots-$key-$_date'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < slots.length; i++)
                      Reveal(
                        delay: i * 40,
                        dy: 10,
                        scaleFrom: 0.8,
                        child: _SlotChip(
                          slot: slots[i],
                          selected: _slot == slots[i].label,
                          color: dok.c1,
                          color2: dok.c2,
                          onTap: slots[i].available
                              ? () => _pickSlot(slots[i].label)
                              : null,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailSection() {
    final poli = _poliList[_poli!];
    final dok = _dok!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const Reveal(
          dx: -16,
          dy: 0,
          child: _StepTitle(4, 'Detail & Konfirmasi',
              sub: 'Periksa kembali sebelum memesan'),
        ),
        const SizedBox(height: 12),
        Reveal(delay: 80, child: _typeSwitch()),
        const SizedBox(height: 10),
        Reveal(
          delay: 160,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: glassDecoration(radius: 18, opacity: 0.65),
            child: TextField(
              controller: _complaint,
              maxLines: 3,
              minLines: 2,
              maxLength: 120,
              textInputAction: TextInputAction.done,
              style: appText(13),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: '',
                icon: const Icon(Icons.edit_note_rounded,
                    size: 20, color: AppColors.outline),
                hintText: 'Keluhan singkat (opsional)',
                hintStyle: appText(13, c: AppColors.outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Reveal(
          delay: 240,
          dy: 28,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration(radius: 26, opacity: 0.7).copyWith(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
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
                          gradient: LinearGradient(colors: [poli.c1, poli.c2]),
                        ),
                        child: Icon(poli.icon, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RINGKASAN BOOKING',
                              style: appText(9,
                                  w: FontWeight.w700,
                                  c: AppColors.primary,
                                  ls: 0.8)),
                          Text(poli.full,
                              style: appText(14, w: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SumRow(Icons.person_rounded, 'Dokter', dok.name),
                _SumRow(Icons.event_rounded, 'Tanggal', _fmtDate(_days[_date])),
                _SumRow(Icons.schedule_rounded, 'Jam', '$_slot WIB'),
                _SumRow(Icons.badge_rounded, 'Pasien',
                    _type == 0 ? 'Pasien Umum' : 'BPJS Kesehatan'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Reveal(
          delay: 340,
          dy: 22,
          child: _SubmitButton(
            label: 'Konfirmasi Booking',
            icon: Icons.check_circle_outline_rounded,
            loading: _submitting,
            onTap: _confirm,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Harap tiba 15 menit sebelum jadwal dan bawa kartu identitas. '
            'Nomor antrean akan aktif setelah booking dikonfirmasi.',
            textAlign: TextAlign.center,
            style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _typeSwitch() {
    const labels = ['Pasien Umum', 'BPJS Kesehatan'];
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            alignment:
                _type == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _type = i);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: appText(12,
                            w: FontWeight.w700,
                            c: _type == i
                                ? Colors.white
                                : AppColors.onSurfaceVariant),
                        child: Text(labels[i]),
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
}

// =============================================================================
// Header
// =============================================================================
class _Header extends StatelessWidget {
  const _Header({required this.scroll, required this.onBack});

  final ValueListenable<double> scroll;
  final VoidCallback onBack;

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
                    Text('Booking ',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                    FlowText('Pemeriksaan',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                  ],
                ),
                Text('Pilih poli, dokter, dan jadwal kunjungan',
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Float(
            dy: 3,
            ms: 2600,
            child: Container(
              width: 38,
              height: 38,
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
              child: const Icon(Icons.event_available_rounded,
                  size: 21, color: AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Kartu intro + stepper
// =============================================================================
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.step});

  final int step;

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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: glassDecoration(radius: 26, opacity: 0.6).copyWith(
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                          Text('Booking Online Aktif',
                              style: appText(11,
                                  w: FontWeight.w700, c: AppColors.success)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Atur jadwal periksa',
                        style:
                            appText(20, w: FontWeight.w700, h: 1.2, ls: -0.3)),
                    FlowText('hanya dalam 4 langkah',
                        style:
                            appText(20, w: FontWeight.w700, h: 1.2, ls: -0.3)),
                  ],
                ),
              ),
              SizedBox(
                width: 62,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Float(
                        dy: 5,
                        ms: 2000,
                        child: _bubble(
                            Icons.calendar_month_rounded, AppColors.primary),
                      ),
                    ),
                    Positioned(
                      right: 30,
                      top: 24,
                      child: Float(
                        dy: 4,
                        ms: 2600,
                        phase: 0.5,
                        child: _bubble(Icons.favorite_rounded, AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StepBar(step: step),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step; // langkah selesai (0..3); langkah aktif = step

  static const _labels = ['Poli', 'Dokter', 'Jadwal', 'Konfirmasi'];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 4; i++) ...[
          _StepDot(index: i, step: step, label: _labels[i]),
          if (i < 3)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, left: 2, right: 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: step > i ? 1 : 0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 3,
                      color: AppColors.primary.withValues(alpha: 0.12),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: v,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                            ),
                          ),
                          child: SizedBox(height: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot(
      {required this.index, required this.step, required this.label});

  final int index;
  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final done = index < step;
    final active = index == step;

    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      alignment: Alignment.center,
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
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
        child: done
            ? const Icon(Icons.check_rounded,
                key: ValueKey('c'), size: 15, color: Colors.white)
            : Text('${index + 1}',
                key: ValueKey('n$active'),
                style: appText(11,
                    w: FontWeight.w700,
                    c: active ? AppColors.primary : AppColors.outline)),
      ),
    );

    if (active) dot = Breathe(amount: 0.1, ms: 1100, child: dot);

    return SizedBox(
      width: 58,
      child: Column(
        children: [
          dot,
          const SizedBox(height: 5),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: appText(9.5,
                w: (done || active) ? FontWeight.w700 : FontWeight.w500,
                c: (done || active)
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant),
            child: Text(label, maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Judul langkah
// =============================================================================
class _StepTitle extends StatelessWidget {
  const _StepTitle(this.n, this.title, {this.sub});

  final int n;
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.cyan],
              ),
            ),
            child: Text('$n',
                style: appText(12, w: FontWeight.w700, c: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: appText(16, w: FontWeight.w700)),
                if (sub != null)
                  Text(sub!, style: appText(11, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bagian yang membuka dengan animasi ukuran saat langkah sebelumnya selesai.
class _Expand extends StatelessWidget {
  const _Expand({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: show ? child : const SizedBox(width: double.infinity),
    );
  }
}

// =============================================================================
// Tile poli
// =============================================================================
class _PoliTile extends StatelessWidget {
  const _PoliTile({
    required this.p,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final _Poli p;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [p.c1, p.c2],
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.c1.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              )
            : glassDecoration(radius: 20, opacity: 0.65).copyWith(
                boxShadow: [
                  BoxShadow(
                    color: p.c1.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: p.c1.withValues(alpha: 0.14),
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Float(
                          dy: 3,
                          ms: 2000 + index * 260,
                          phase: (index * 0.17) % 1.0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : null,
                              gradient: selected
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.bottomLeft,
                                      end: Alignment.topRight,
                                      colors: [p.c1, p.c2],
                                    ),
                              boxShadow: selected
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: p.c1.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Icon(p.icon, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: appText(12,
                              w: FontWeight.w700,
                              c: selected ? Colors.white : AppColors.primary,
                              h: 1.2),
                          child: Text(p.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 2),
                        Text(p.sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: appText(10,
                                c: selected
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 13, color: p.c1),
                    ),
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
// Kartu dokter
// =============================================================================
class _DokCard extends StatelessWidget {
  const _DokCard(
      {required this.d, required this.selected, required this.onTap});

  final _Dok d;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final full = d.quota == 0;
    final low = !full && d.quota <= 2;
    final qc =
        full ? AppColors.error : (low ? AppColors.warning : AppColors.success);
    final quotaIcon = Icon(Icons.groups_rounded, size: 15, color: qc);

    return Pressable(
      enabled: !full,
      scale: 0.97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: glassDecoration(radius: 22, opacity: selected ? 0.95 : 0.65)
            .copyWith(
          border: Border.all(
            color: selected ? d.c1 : Colors.white.withValues(alpha: 0.8),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: d.c1.withValues(alpha: selected ? 0.28 : 0.06),
              blurRadius: selected ? 20 : 10,
              offset: Offset(0, selected ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: d.c1.withValues(alpha: 0.12),
            child: Opacity(
              opacity: full ? 0.7 : 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: appText(16,
                                      w: FontWeight.w700, c: Colors.white)),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
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
                                child: Text(d.spesialis,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: appText(10,
                                        w: FontWeight.w700, c: d.c1)),
                              ),
                              const SizedBox(height: 4),
                              Text(d.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appText(14, w: FontWeight.w700)),
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 3),
                                  Text(d.time,
                                      style: appText(11,
                                          c: AppColors.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [d.c1, d.c2]),
                            ),
                            child: const Icon(Icons.check_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    if (d.note != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Breathe(
                              amount: 0.3,
                              ms: 900,
                              child: Icon(Icons.update_rounded,
                                  size: 13, color: AppColors.warning),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(d.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: appText(10,
                                      w: FontWeight.w600,
                                      c: AppColors.warning)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (low)
                          Breathe(amount: 0.3, ms: 800, child: quotaIcon)
                        else
                          quotaIcon,
                        const SizedBox(width: 4),
                        Text(full ? 'Kuota penuh' : 'Sisa kuota ${d.quota}',
                            style: appText(11, w: FontWeight.w700, c: qc)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Chip tanggal & jam
// =============================================================================
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.day,
    required this.today,
    required this.selected,
    required this.closed,
    required this.onTap,
  });

  final DateTime day;
  final bool today;
  final bool selected;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? Colors.white
        : closed
            ? Colors.grey.shade500
            : AppColors.onSurfaceVariant;
    return Pressable(
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [AppColors.primary, AppColors.primaryContainer])
              : null,
          color: selected
              ? null
              : closed
                  ? Colors.grey.shade200.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.7),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  AppColors.primary.withValues(alpha: selected ? 0.32 : 0.05),
              blurRadius: selected ? 16 : 8,
              offset: Offset(0, selected ? 6 : 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(today ? 'Hari ini' : _hari[day.weekday - 1],
                    maxLines: 1,
                    style: appText(today ? 9 : 11, w: FontWeight.w600, c: fg)),
                const SizedBox(height: 2),
                Text('${day.day}',
                    style: appText(20,
                        w: FontWeight.w700,
                        c: selected
                            ? Colors.white
                            : closed
                                ? Colors.grey.shade500
                                : AppColors.primary,
                        ls: -0.3)),
                Text(closed ? 'Tutup' : _bulan[day.month - 1],
                    style: appText(10, c: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.color,
    required this.color2,
    required this.onTap,
  });

  final _Slot slot;
  final bool selected;
  final Color color;
  final Color color2;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ok = slot.available;
    return Pressable(
      enabled: ok,
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected ? LinearGradient(colors: [color, color2]) : null,
          color: selected
              ? null
              : ok
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.grey.shade200,
          border: Border.all(
            color: selected
                ? Colors.transparent
                : ok
                    ? color.withValues(alpha: 0.3)
                    : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                slot.label,
                style: appText(12,
                        w: FontWeight.w700,
                        c: selected
                            ? Colors.white
                            : ok
                                ? color
                                : Colors.grey.shade500)
                    .copyWith(
                  decoration:
                      ok ? TextDecoration.none : TextDecoration.lineThrough,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Ringkasan
// =============================================================================
class _SumRow extends StatelessWidget {
  const _SumRow(this.icon, this.label, this.value);

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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (cur, prev) => Stack(
                alignment: Alignment.centerRight,
                children: [...prev, if (cur != null) cur],
              ),
              child: Text(
                value,
                key: ValueKey(value),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: appText(12, w: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol gradien dengan kilau menyapu + status loading.
class _SubmitButton extends StatefulWidget {
  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
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
        height: 50,
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
            onTap: widget.loading ? null : widget.onTap,
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: widget.loading
                        ? const SizedBox(
                            key: ValueKey('load'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Row(
                            key: const ValueKey('label'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(widget.label,
                                  style: appText(13,
                                      w: FontWeight.w700, c: Colors.white)),
                              const SizedBox(width: 6),
                              Icon(widget.icon, size: 18, color: Colors.white),
                            ],
                          ),
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
// Dialog sukses (centang memantul + ledakan partikel + nomor antrean)
// =============================================================================
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = [
      AppColors.primary,
      AppColors.cyan,
      AppColors.success,
      AppColors.tertiary,
      AppColors.warning,
    ];
    final center = size.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t);
    final paint = Paint();
    for (var i = 0; i < 20; i++) {
      final a = i * 2 * math.pi / 20 + (i.isOdd ? 0.14 : 0);
      final dist = (i.isEven ? 68.0 : 98.0) * e;
      final r = (i.isEven ? 4.0 : 3.0) * (1 - t * 0.6);
      paint.color = cols[i % cols.length]
          .withValues(alpha: (1 - t).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(
        center + Offset(math.cos(a) * dist, math.sin(a) * dist),
        r,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog({
    required this.queue,
    required this.code,
    required this.poli,
    required this.doctor,
    required this.dateText,
    required this.time,
    required this.onQueue,
    required this.onClose,
  });

  final String queue;
  final String code;
  final String poli;
  final String doctor;
  final String dateText;
  final String time;
  final VoidCallback onQueue;
  final VoidCallback onClose;

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        HapticFeedback.heavyImpact();
        _burst.forward();
      }
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Text(l, style: appText(11, c: AppColors.onSurfaceVariant)),
            ),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: appText(12, w: FontWeight.w700)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _burst,
                              builder: (_, __) => CustomPaint(
                                  painter: _BurstPainter(_burst.value)),
                            ),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: Breathe(
                            amount: 0.06,
                            ms: 1600,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                  colors: [AppColors.success, AppColors.cyan],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.success
                                        .withValues(alpha: 0.4),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 44, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Reveal(
                    delay: 350,
                    dy: 14,
                    child: FlowText('Booking Berhasil!',
                        style: appText(22, w: FontWeight.w700, ls: -0.4)),
                  ),
                  const SizedBox(height: 4),
                  Reveal(
                    delay: 450,
                    dy: 10,
                    child: Text('Simpan nomor antrean Anda di bawah ini',
                        style: appText(12, c: AppColors.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 550,
                    dy: 20,
                    scaleFrom: 0.85,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: AppColors.primary.withValues(alpha: 0.07),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18)),
                      ),
                      child: Column(
                        children: [
                          Text('NOMOR ANTREAN',
                              style: appText(10,
                                  w: FontWeight.w700,
                                  c: AppColors.primary,
                                  ls: 1)),
                          const SizedBox(height: 2),
                          FlowText(widget.queue,
                              style: appText(38, w: FontWeight.w800, ls: -0.8)),
                          Text('Kode booking ${widget.code}',
                              style:
                                  appText(11, c: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Reveal(
                    delay: 680,
                    dy: 14,
                    child: Column(
                      children: [
                        _row('Poli', widget.poli),
                        _row('Dokter', widget.doctor),
                        _row(
                            'Jadwal', '${widget.dateText}\n${widget.time} WIB'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: 800,
                    dy: 18,
                    child: _SubmitButton(
                      label: 'Lihat Antrean Saya',
                      icon: Icons.arrow_forward_rounded,
                      onTap: widget.onQueue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: widget.onClose,
                    child: Text('Selesai',
                        style: appText(12,
                            w: FontWeight.w700, c: AppColors.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
