import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../services/clinic_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/anim.dart';
import '../widgets/sub_page.dart';

enum _Urg { ringan, klinik, darurat }

extension _UrgX on _Urg {
  String get label => switch (this) {
        _Urg.ringan => 'Ringan',
        _Urg.klinik => 'Perlu ke klinik',
        _Urg.darurat => 'Darurat',
      };

  Color get color => switch (this) {
        _Urg.ringan => AppColors.success,
        _Urg.klinik => AppColors.warning,
        _Urg.darurat => AppColors.error,
      };
}

class _Topic {
  const _Topic(
      this.title, this.icon, this.urg, this.summary, this.steps, this.warn);

  final String title;
  final IconData icon;
  final _Urg urg;
  final String summary;
  final List<String> steps;
  final String warn;

  factory _Topic.fromJson(Map<String, dynamic> row) {
    final urgency = (row['urgency'] ?? 'ringan')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    final _Urg urg = switch (urgency) {
      'darurat' || 'emergency' || 'critical' || 'urgent' => _Urg.darurat,
      'klinik' ||
      'perlu_ke_klinik' ||
      'needs_clinic' ||
      'clinic' ||
      'moderate' =>
        _Urg.klinik,
      _ => _Urg.ringan,
    };

    final rawSteps = row['first_aid_steps'];
    final steps = rawSteps is List
        ? (rawSteps
            .whereType<Map>()
            .map((step) => Map<String, dynamic>.from(step))
            .toList()
          ..sort(
              (a, b) => _asInt(a['step_no']).compareTo(_asInt(b['step_no']))))
        : <Map<String, dynamic>>[];

    return _Topic(
      (row['title'] ?? 'Panduan pertolongan pertama').toString(),
      _iconFromKey(row['icon_key']?.toString()),
      urg,
      (row['summary'] ?? '').toString(),
      steps
          .map((step) => (step['content'] ?? '').toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      (row['warning_text'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  static IconData _iconFromKey(String? key) {
    return switch ((key ?? '').toLowerCase()) {
      'thermostat' || 'fever' => Icons.thermostat_rounded,
      'healing' || 'wound' => Icons.healing_rounded,
      'fire' || 'burn' => Icons.local_fire_department_rounded,
      'water' || 'nosebleed' => Icons.water_drop_rounded,
      'drink' || 'diarrhea' => Icons.local_drink_rounded,
      'choking' => Icons.record_voice_over_rounded,
      'heart' || 'cardiac' => Icons.monitor_heart_rounded,
      'air' || 'breathing' || 'allergy' => Icons.air_rounded,
      'brain' || 'stroke' => Icons.psychology_rounded,
      _ => Icons.medical_services_rounded,
    };
  }
}

/// Panduan penanganan awal diambil dari Supabase.
class FirstAidScreen extends StatefulWidget {
  const FirstAidScreen({super.key});

  @override
  State<FirstAidScreen> createState() => _FirstAidScreenState();
}

class _FirstAidScreenState extends State<FirstAidScreen> {
  static const _filters = ['Semua', 'Ringan', 'Perlu ke klinik', 'Darurat'];
  int _f = 0;
  late Future<_FirstAidData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_FirstAidData> _loadData() async {
    final results = await Future.wait([
      ClinicRepository.instance.firstAidTopics(),
      ClinicRepository.instance.emergencyNumbers(),
    ]);
    final topics =
        (results[0] as List<Json>).map(_Topic.fromJson).toList(growable: false);
    final numbers = results[1] as List<Json>;
    return _FirstAidData(topics: topics, emergencyNumbers: numbers);
  }

  Future<void> _reload() async {
    setState(() => _future = _loadData());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Panduan Awal',
      subtitle: 'Pertolongan pertama & urgensi gejala',
      icon: Icons.health_and_safety_rounded,
      accent: AppColors.secondary,
      accent2: AppColors.cyan,
      children: [
        FutureBuilder<_FirstAidData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 44),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return _FirstAidMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Panduan belum dapat dimuat',
                message: 'Periksa koneksi internet, lalu coba muat ulang.',
                actionLabel: 'Coba lagi',
                onAction: _reload,
              );
            }

            final data = snapshot.data;
            final topics = data?.topics ?? const <_Topic>[];
            final numbers = data?.emergencyNumbers ?? const <Json>[];
            final filtered = _f == 0
                ? topics
                : topics.where((topic) => topic.urg.index == _f - 1).toList();

            final emergency = numbers.isNotEmpty ? numbers.first : null;
            final emergencyPhone =
                (emergency?['phone_number'] ?? '112').toString();
            final emergencyLabel =
                (emergency?['label'] ?? 'Nomor darurat').toString();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EmergencyBanner(
                  label: emergencyLabel,
                  phone: emergencyPhone,
                  onCopy: () {
                    Clipboard.setData(ClipboardData(text: emergencyPhone));
                    showToast(context, 'Nomor $emergencyPhone disalin');
                  },
                ),
                const SizedBox(height: 14),
                ChipBar(
                  options: _filters,
                  selected: _f,
                  color:
                      _f == 0 ? AppColors.primary : _Urg.values[_f - 1].color,
                  onChanged: (i) => setState(() => _f = i),
                ),
                const SizedBox(height: 16),
                if (topics.isEmpty)
                  const _FirstAidMessage(
                    icon: Icons.medical_information_outlined,
                    title: 'Belum ada panduan',
                    message:
                        'Panduan pertolongan pertama belum tersedia. Silakan cek kembali nanti.',
                  )
                else if (filtered.isEmpty)
                  const _FirstAidMessage(
                    icon: Icons.filter_list_off_rounded,
                    title: 'Tidak ada panduan',
                    message: 'Belum ada panduan pada kategori ini.',
                  )
                else
                  for (final topic in filtered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _TopicCard(topic: topic),
                    ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Informasi ini bersifat edukatif dan bukan pengganti diagnosis '
                    'atau konsultasi tenaga medis. Untuk kondisi darurat, segera '
                    'cari pertolongan medis.',
                    style:
                        appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FirstAidData {
  const _FirstAidData({
    required this.topics,
    required this.emergencyNumbers,
  });

  final List<_Topic> topics;
  final List<Json> emergencyNumbers;
}

class _FirstAidMessage extends StatelessWidget {
  const _FirstAidMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title, style: appText(13, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: appText(11.5, c: AppColors.onSurfaceVariant, h: 1.4),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
                onPressed: onAction, child: Text(actionLabel ?? 'Coba lagi')),
          ],
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({
    required this.label,
    required this.phone,
    required this.onCopy,
  });

  final String label;
  final String phone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Breathe(
            amount: 0.12,
            ms: 1100,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.emergency_rounded,
                  color: AppColors.error, size: 23),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kondisi darurat?',
                    style: appText(14, w: FontWeight.w700, c: AppColors.error)),
                const SizedBox(height: 2),
                Text('Hubungi $phone ($label) sekarang.',
                    style: appText(11, c: AppColors.onSurfaceVariant, h: 1.35)),
              ],
            ),
          ),
          Pressable(
            scale: 0.9,
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Salin $phone',
                    style: appText(11, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatefulWidget {
  const _TopicCard({required this.topic});

  final _Topic topic;

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    final c = t.urg.color;
    return GlassCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(t.icon, color: c, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title, style: appText(14, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    StatusPill(t.urg.label, c),
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
          const SizedBox(height: 8),
          Text(t.summary,
              style: appText(12, c: AppColors.onSurfaceVariant, h: 1.4)),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      for (var i = 0; i < t.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text('${i + 1}',
                                    style: appText(11,
                                        w: FontWeight.w700,
                                        c: AppColors.primary)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(t.steps[i],
                                    style: appText(12.5, h: 1.45)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 15, color: AppColors.error),
                                const SizedBox(width: 5),
                                Text('Segera cari bantuan medis bila:',
                                    style: appText(11,
                                        w: FontWeight.w700,
                                        c: AppColors.error)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(t.warn, style: appText(11.5, h: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
