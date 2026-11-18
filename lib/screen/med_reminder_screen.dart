import 'package:flutter/material.dart';

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';

class _Rem {
  _Rem({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    required this.rule,
    this.active = true,
    this.taken = false,
  });

  factory _Rem.fromJson(Json j) {
    final parts = (j['remind_time'] as String).split(':');
    return _Rem(
      id: j['id'] as String,
      name: (j['medicine_name'] ?? '').toString(),
      dose: (j['dose'] ?? '').toString(),
      time: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      rule: (j['usage_rule'] ?? '').toString(),
      active: j['is_active'] as bool? ?? true,
      taken: j['taken'] as bool? ?? false,
    );
  }

  final String id;
  String name;
  String dose;
  TimeOfDay time;
  String rule;
  bool active;
  bool taken;

  int get minutes => time.hour * 60 + time.minute;
}

typedef _NewRem = (String, String, TimeOfDay, String);

/// Pengingat obat. Data diambil dari Supabase (tabel medication_reminders dan
/// medication_intake_logs). Untuk notifikasi sungguhan sambungkan ke
/// flutter_local_notifications / backend.
class MedReminderScreen extends StatefulWidget {
  const MedReminderScreen({super.key});

  @override
  State<MedReminderScreen> createState() => _MedReminderScreenState();
}

class _MedReminderScreenState extends State<MedReminderScreen> {
  final _repo = ClinicRepository.instance;
  List<_Rem> _items = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] = muat ulang tanpa menampilkan spinner (data lama tetap tampil).
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final rows = await _repo.todayReminders();
      if (!mounted) return;
      setState(() {
        _items = rows.map(_Rem.fromJson).toList();
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) {
        showToast(context, 'Gagal memuat pengingat');
      } else {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  String _hms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _toggleTaken(_Rem r) async {
    final v = !r.taken;
    setState(() => r.taken = v);
    try {
      await _repo.setMedicationTaken(r.id, v);
    } catch (_) {
      if (!mounted) return;
      setState(() => r.taken = !v);
      showToast(context, 'Gagal menyimpan, coba lagi');
    }
  }

  Future<void> _toggleActive(_Rem r, bool v) async {
    setState(() => r.active = v);
    try {
      await _repo.setReminderActive(r.id, v);
    } catch (_) {
      if (!mounted) return;
      setState(() => r.active = !v);
      showToast(context, 'Gagal menyimpan, coba lagi');
    }
  }

  Future<void> _delete(_Rem r) async {
    setState(() => _items.removeWhere((e) => e.id == r.id));
    try {
      await _repo.deleteReminder(r.id);
      if (!mounted) return;
      showToast(context, '${r.name} dihapus');
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Gagal menghapus, coba lagi');
      _load(silent: true);
    }
  }

  List<_Rem> get _sorted =>
      [..._items]..sort((a, b) => a.minutes.compareTo(b.minutes));

  _Rem? get _next {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    final pend = _sorted.where((r) => r.active && !r.taken).toList();
    if (pend.isEmpty) return null;
    return pend.firstWhere((r) => r.minutes >= nowMin,
        orElse: () => pend.first);
  }

  Future<void> _add() async {
    final res = await showModalBottomSheet<_NewRem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddSheet(),
    );
    if (res == null || !mounted) return;
    try {
      await _repo.addReminder(
        name: res.$1,
        dose: res.$2,
        rule: res.$4,
        time: _hms(res.$3),
      );
    } catch (_) {
      if (!mounted) return;
      showToast(context, 'Gagal menambahkan pengingat');
      return;
    }
    if (!mounted) return;
    await _load(silent: true);
    if (!mounted) return;
    showToast(context, 'Pengingat ditambahkan');
  }

  Widget _summary() {
    final active = _items.where((r) => r.active).toList();
    final done = active.where((r) => r.taken).length;
    final total = active.length;
    final p = total == 0 ? 0.0 : done / total;
    final next = _next;
    return GlassCard(
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: p),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      color: p >= 1 ? AppColors.success : AppColors.primary,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Text('$done/$total', style: appText(14, w: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PROGRES HARI INI',
                    style: appText(9,
                        w: FontWeight.w700, c: AppColors.primary, ls: 0.8)),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? 'Belum ada pengingat aktif'
                      : (done == total
                          ? 'Semua obat hari ini sudah diminum 🎉'
                          : '${total - done} dosis lagi hari ini'),
                  style: appText(14, w: FontWeight.w700, h: 1.3),
                ),
                if (next != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                        'Berikutnya: ${next.name} • ${fmtTime(next.time)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(_Rem r, bool isNext) {
    final c = r.taken ? AppColors.success : AppColors.primary;
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _delete(r),
      child: Opacity(
        opacity: r.active ? 1 : 0.55,
        child: Container(
          decoration: isNext
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                )
              : null,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                          r.taken
                              ? Icons.check_circle_rounded
                              : Icons.alarm_rounded,
                          size: 18,
                          color: c),
                      const SizedBox(height: 2),
                      Text(fmtTime(r.time),
                          style: appText(12, w: FontWeight.w700, c: c)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: appText(13.5, w: FontWeight.w700)),
                          ),
                          if (isNext) ...[
                            const SizedBox(width: 6),
                            const StatusPill('Berikutnya', AppColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${r.dose} • ${r.rule}',
                          style: appText(11, c: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Pressable(
                        enabled: r.active,
                        scale: 0.92,
                        child: InkWell(
                          onTap: r.active ? () => _toggleTaken(r) : null,
                          borderRadius: BorderRadius.circular(999),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: r.taken
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.primary,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (r.taken)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.check_rounded,
                                        size: 13, color: AppColors.success),
                                  ),
                                Text(r.taken ? 'Sudah diminum' : 'Tandai minum',
                                    style: appText(11,
                                        w: FontWeight.w700,
                                        c: r.taken
                                            ? AppColors.success
                                            : Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: r.active,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => _toggleActive(r, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    final next = _next;
    return SubPage(
      title: 'Pengingat Obat',
      subtitle: 'Notifikasi dosis',
      icon: Icons.alarm_rounded,
      accent: AppColors.tertiary,
      accent2: AppColors.tertiaryContainer,
      floating: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Tambah',
            style: appText(13, w: FontWeight.w700, c: Colors.white)),
      ),
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
                'Pengingat belum dapat dimuat.\nPeriksa koneksi internet, lalu coba lagi.',
          ),
          Center(
            child: TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ),
        ] else ...[
          _summary(),
          const SectionLabel('Jadwal Hari Ini'),
          if (sorted.isEmpty)
            const EmptyCard(
              icon: Icons.medication_outlined,
              text:
                  'Belum ada pengingat.\nKetuk "Tambah" untuk membuat jadwal minum obat.',
            )
          else
            for (final r in sorted) _tile(r, identical(r, next)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Geser kartu ke kiri untuk menghapus. Ikuti dosis dan aturan pakai '
              'sesuai resep dokter.',
              style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// Bottom sheet tambah pengingat
// =============================================================================
class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  static const _rules = [
    'Sebelum makan',
    'Sesudah makan',
    'Bersama makan',
    'Sebelum tidur',
  ];

  final _name = TextEditingController();
  final _dose = TextEditingController(text: '1 tablet');
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _rule = 1;
  bool _err = false;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = true);
      return;
    }
    final dose = _dose.text.trim().isEmpty ? '1 dosis' : _dose.text.trim();
    Navigator.of(context).pop<_NewRem>((name, dose, _time, _rules[_rule]));
  }

  InputDecoration _dec(String hint, {String? error}) => InputDecoration(
        hintText: hint,
        errorText: error,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Pengingat Obat Baru',
                  style: appText(17, w: FontWeight.w700)),
              const SizedBox(height: 14),
              Text('Nama obat', style: appText(12, w: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_err) setState(() => _err = false);
                },
                decoration: _dec('mis. Paracetamol 500 mg',
                    error: _err ? 'Nama obat wajib diisi' : null),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dosis', style: appText(12, w: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                            controller: _dose, decoration: _dec('1 tablet')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Jam', style: appText(12, w: FontWeight.w600)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pick,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(fmtTime(_time),
                                    style: appText(14, w: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Aturan pakai', style: appText(12, w: FontWeight.w600)),
              const SizedBox(height: 6),
              ChipBar(
                options: _rules,
                selected: _rule,
                onChanged: (i) => setState(() => _rule = i),
              ),
              const SizedBox(height: 18),
              Pressable(
                scale: 0.97,
                child: InkWell(
                  onTap: _save,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(colors: [
                        AppColors.primaryContainer,
                        AppColors.primary
                      ]),
                    ),
                    child: Text('Simpan Pengingat',
                        style:
                            appText(13, w: FontWeight.w700, c: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
