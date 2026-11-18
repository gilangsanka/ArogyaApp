import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;

import '../theme/app_colors.dart';
import '../services/clinic_repository.dart';
import '../widgets/anim.dart';
import 'antrean_screen.dart' show QueueTicket;

// =============================================================================
// Model data pasien (ganti dengan data dari server)
// =============================================================================
class PatientProfile {
  const PatientProfile({
    required this.name,
    required this.rm,
    required this.nik,
    required this.birth,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    required this.blood,
    required this.allergies,
    required this.chronic,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.bpjs,
  });

  final String name;
  final String rm; // nomor rekam medis
  final String nik; // sudah disamarkan
  final String birth;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String blood;
  final List<String> allergies;
  final String chronic;
  final String emergencyName;
  final String emergencyPhone;
  final String? bpjs;

  PatientProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
  }) =>
      PatientProfile(
        name: name ?? this.name,
        rm: rm,
        nik: nik,
        birth: birth,
        gender: gender,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        blood: blood,
        allergies: allergies,
        chronic: chronic,
        emergencyName: emergencyName,
        emergencyPhone: emergencyPhone,
        bpjs: bpjs,
      );

  String get initials {
    final parts =
        name.split(' ').where((p) => p.isNotEmpty && !p.endsWith('.')).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static const demo = PatientProfile(
    name: 'Andini Putri Lestari',
    rm: 'RM-002481',
    nik: '3273 **** **** 0004',
    birth: '14 Mei 1996',
    gender: 'Perempuan',
    phone: '0812-3456-7890',
    email: 'andini.putri@email.com',
    address: 'Jl. Dago Asri No. 12, Coblong, Kota Bandung',
    blood: 'O+',
    allergies: ['Penisilin', 'Seafood'],
    chronic: 'Tidak ada',
    emergencyName: 'Rudi Lestari (Ayah)',
    emergencyPhone: '0813-9876-5432',
    bpjs: '0001234567890',
  );
}

// =============================================================================
// Halaman Profil.
// [onNavigate]: 0 = Beranda, 1 = Booking, 2 = Antrean, 3 = Profil.
// [ticket]: antrean aktif (jika ada), ditampilkan sebagai pintasan.
// =============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onNavigate,
    this.ticket,
    this.profile = PatientProfile.demo,
    this.onLogout,
  });

  final ValueChanged<int> onNavigate;
  final QueueTicket? ticket;
  final PatientProfile profile;
  final VoidCallback? onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  late PatientProfile _p = widget.profile;

  bool _notifQueue = true;
  bool _notifMed = true;
  bool _biometric = false;
  bool _loadingProfile = true;
  bool _saving = false;
  bool _loggingOut = false;
  int _visits = 0;
  int _activeRx = 0;
  int _activeBookings = 0;
  String? _loadError;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    _loadFromDatabase();
    _ctrl.addListener(() {
      _scroll.value =
          _ctrl.hasClients ? _ctrl.offset.clamp(0.0, 1e9).toDouble() : 0.0;
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen old) {
    super.didUpdateWidget(old);
    if (!identical(widget.profile, old.profile)) _p = widget.profile;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _text(dynamic value, [String fallback = 'Belum diisi']) {
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  String _maskNik(dynamic value) {
    final raw = _text(value, 'Belum diisi');
    if (raw == 'Belum diisi' || raw.length < 8) return raw;
    return '${raw.substring(0, 4)} **** **** ${raw.substring(raw.length - 4)}';
  }

  String _formatBirth(dynamic value) {
    if (value == null || value.toString().isEmpty) return 'Belum diisi';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadFromDatabase() async {
    try {
      final repo = ClinicRepository.instance;
      final values = await Future.wait<dynamic>([
        repo.patientProfile(),
        repo.profileStats(),
      ]);
      if (!mounted) return;
      final data = values[0] as Map<String, dynamic>;
      final stats =
          values[1] as ({int visits, int activeRx, int activeBookings});
      final allergyRows = List<Map<String, dynamic>>.from(
          (data['allergies'] as List? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      final allergies =
          allergyRows.map((e) => e['allergen'].toString()).toList();
      setState(() {
        _profileData = data;
        _p = PatientProfile(
          name: _text(data['full_name'], 'Nama belum diisi'),
          rm: _text(data['medical_record_no'], '-'),
          nik: _maskNik(data['nik']),
          birth: _formatBirth(data['birth_date']),
          gender: data['gender'] == 'laki_laki'
              ? 'Laki-laki'
              : data['gender'] == 'perempuan'
                  ? 'Perempuan'
                  : 'Belum diisi',
          phone: _text(data['phone'], ''),
          email: _text(data['email'], ''),
          address: _text(data['address'], ''),
          blood: _text(data['blood_type'], '-'),
          allergies: allergies,
          chronic: _text(data['chronic_conditions'], 'Tidak ada'),
          emergencyName: _text(data['emergency_contact_name'], 'Belum diisi'),
          emergencyPhone: _text(data['emergency_contact_phone'], 'Belum diisi'),
          bpjs: (data['bpjs_number'] as String?)?.trim().isNotEmpty == true
              ? data['bpjs_number'] as String
              : null,
        );
        _notifQueue = data['notify_queue'] as bool? ?? true;
        _notifMed = data['notify_medication'] as bool? ?? true;
        _biometric = data['biometric_lock'] as bool? ?? false;
        _visits = stats.visits;
        _activeRx = stats.activeRx;
        _activeBookings = stats.activeBookings;
        _loadingProfile = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _loadError = e.toString();
      });
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ));
  }

  void _soon(String label) => _snack('$label — segera hadir');

  Future<void> _edit() async {
    HapticFeedback.selectionClick();
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _EditSheet(profile: _p, data: _profileData),
    );
    if (res != null && mounted) {
      setState(() => _saving = true);
      try {
        await ClinicRepository.instance.updateMyProfile(data: res);
        await _loadFromDatabase();
        if (!mounted) return;
        setState(() => _saving = false);
        _snack('Profil berhasil diperbarui');
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        _snack('Gagal menyimpan profil: $e');
      }
    }
  }

  Future<void> _copyBpjs() async {
    final n = _p.bpjs;
    if (n == null) return;
    await Clipboard.setData(ClipboardData(text: n));
    HapticFeedback.lightImpact();
    if (mounted) _snack('Nomor BPJS disalin');
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title:
            Text('Keluar dari akun?', style: appText(16, w: FontWeight.w700)),
        content: Text(
          'Anda perlu masuk kembali untuk melihat antrean dan rekam medis.',
          style: appText(13, c: AppColors.onSurfaceVariant, h: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal',
                style: appText(12,
                    w: FontWeight.w700, c: AppColors.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Keluar',
                style: appText(12, w: FontWeight.w700, c: AppColors.error)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      // Akhiri sesi lokal Supabase agar proses logout tidak menunggu
      // permintaan logout global ke server.
      await ClinicRepository.instance.signOut();
      if (!mounted) return;

      // Route '/' adalah SplashRoute yang ditetapkan sebagai home di main.dart.
      // Hapus seluruh halaman sebelumnya agar tombol Back tidak kembali ke
      // MainShell / halaman profil setelah logout.
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      _snack('Gagal keluar dari akun: $e');
    }
  }

  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
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
                  onEdit: _edit,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _ctrl,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    if (_loadingProfile)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_loadError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Gagal memuat profil: $_loadError',
                            style: appText(11, c: AppColors.error)),
                      ),
                    Reveal(
                      delay: 60,
                      dy: 30,
                      scaleFrom: 0.96,
                      child: _ProfileCard(p: _p, onEdit: _edit),
                    ),
                    const SizedBox(height: 14),
                    Reveal(
                      delay: 160,
                      dy: 24,
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.history_rounded,
                              value: _loadingProfile ? '...' : '$_visits',
                              label: 'Kunjungan',
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.receipt_long_rounded,
                              value: _loadingProfile ? '...' : '$_activeRx',
                              label: 'Resep aktif',
                              color: AppColors.tertiary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.confirmation_number_rounded,
                              value:
                                  _loadingProfile ? '...' : '$_activeBookings',
                              label: 'Booking aktif',
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (t != null) ...[
                      const SizedBox(height: 14),
                      Reveal(
                        delay: 240,
                        dy: 22,
                        child: _TicketShortcut(
                          t: t,
                          onTap: () => widget.onNavigate(2),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Reveal(
                      delay: 300,
                      dx: -16,
                      dy: 0,
                      child: _SectionTitle('Data Diri'),
                    ),
                    const SizedBox(height: 10),
                    Reveal(
                      delay: 340,
                      dy: 22,
                      child: _GlassCard(children: [
                        _InfoRow(Icons.badge_rounded, 'NIK', _p.nik),
                        _InfoRow(Icons.cake_rounded, 'Tanggal lahir', _p.birth),
                        _InfoRow(Icons.wc_rounded, 'Jenis kelamin', _p.gender),
                        _InfoRow(Icons.phone_rounded, 'No. HP', _p.phone),
                        _InfoRow(Icons.mail_rounded, 'Email', _p.email),
                        _InfoRow(Icons.home_rounded, 'Alamat', _p.address,
                            multiline: true),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    const Reveal(
                      delay: 380,
                      dx: -16,
                      dy: 0,
                      child: _SectionTitle('Informasi Medis'),
                    ),
                    const SizedBox(height: 10),
                    Reveal(delay: 420, dy: 22, child: _medicalCard()),
                    if (_p.bpjs != null) ...[
                      const SizedBox(height: 14),
                      Reveal(
                        delay: 460,
                        dy: 22,
                        child: _BpjsCard(number: _p.bpjs!, onCopy: _copyBpjs),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Reveal(
                      delay: 500,
                      dx: -16,
                      dy: 0,
                      child: _SectionTitle('Pengaturan'),
                    ),
                    const SizedBox(height: 10),
                    Reveal(delay: 540, dy: 22, child: _settingsCard()),
                    const SizedBox(height: 20),
                    Reveal(
                      delay: 620,
                      dy: 16,
                      child:
                          _LogoutButton(onTap: _logout, loading: _loggingOut),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text('Arogya App • versi 1.0.0',
                          style: appText(10.5, c: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _medicalCard() {
    return _GlassCard(children: [
      Row(
        children: [
          _iconBox(Icons.bloodtype_rounded, AppColors.error),
          const SizedBox(width: 10),
          Text('Golongan darah',
              style: appText(11, c: AppColors.onSurfaceVariant)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_p.blood,
                style: appText(13, w: FontWeight.w800, c: AppColors.error)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconBox(Icons.warning_amber_rounded, AppColors.warning),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Alergi',
                style: appText(11, c: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_p.allergies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Tidak ada',
                        style: appText(12, w: FontWeight.w700)),
                  )
                else
                  for (final a in _p.allergies)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(a,
                          style: appText(11,
                              w: FontWeight.w700, c: AppColors.warning)),
                    ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      _InfoRow(Icons.monitor_heart_rounded, 'Penyakit kronis', _p.chronic),
      _InfoRow(Icons.contact_phone_rounded, 'Kontak darurat', _p.emergencyName),
      _InfoRow(Icons.call_rounded, 'No. darurat', _p.emergencyPhone),
    ]);
  }

  Future<void> _saveSetting(String key, bool value) async {
    final old = key == 'queue'
        ? _notifQueue
        : key == 'medication'
            ? _notifMed
            : _biometric;
    setState(() {
      if (key == 'queue') _notifQueue = value;
      if (key == 'medication') _notifMed = value;
      if (key == 'biometric') _biometric = value;
    });
    try {
      await ClinicRepository.instance.updateMySettings(
        notifQueue: key == 'queue' ? value : null,
        notifMedication: key == 'medication' ? value : null,
        biometricLock: key == 'biometric' ? value : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (key == 'queue') _notifQueue = old;
        if (key == 'medication') _notifMed = old;
        if (key == 'biometric') _biometric = old;
      });
      _snack('Pengaturan gagal disimpan: $e');
    }
  }

  Widget _settingsCard() {
    return _GlassCard(children: [
      _ToggleRow(
        icon: Icons.notifications_active_rounded,
        color: AppColors.primary,
        title: 'Notifikasi antrean',
        sub: 'Beritahu saat giliran mendekat',
        value: _notifQueue,
        onChanged: (v) => _saveSetting('queue', v),
      ),
      _ToggleRow(
        icon: Icons.alarm_rounded,
        color: AppColors.tertiary,
        title: 'Pengingat obat',
        sub: 'Notifikasi jadwal minum obat',
        value: _notifMed,
        onChanged: (v) => _saveSetting('medication', v),
      ),
      _ToggleRow(
        icon: Icons.fingerprint_rounded,
        color: AppColors.success,
        title: 'Kunci biometrik',
        sub: 'Amankan data medis Anda',
        value: _biometric,
        onChanged: (v) => _saveSetting('biometric', v),
      ),
      _NavRow(
        Icons.language_rounded,
        'Bahasa • Indonesia',
        AppColors.secondary,
        () => _soon('Pilihan bahasa'),
      ),
    ]);
  }
}

Widget _iconBox(IconData icon, Color color) => Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 15, color: color),
    );

// =============================================================================
// Header
// =============================================================================
class _Header extends StatelessWidget {
  const _Header(
      {required this.scroll, required this.onBack, required this.onEdit});

  final ValueListenable<double> scroll;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  Widget _circle(IconData icon, VoidCallback onTap) => Pressable(
        scale: 0.88,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      );

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
          _circle(Icons.arrow_back_rounded, onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Profil ',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                    FlowText('Saya',
                        style: appText(17, w: FontWeight.w700, ls: -0.3)),
                  ],
                ),
                Text('Data diri & pengaturan akun',
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          _circle(Icons.edit_rounded, onEdit),
        ],
      ),
    );
  }
}

// =============================================================================
// Kartu profil
// =============================================================================
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.p, required this.onEdit});

  final PatientProfile p;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final bpjs = p.bpjs != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(radius: 28, opacity: 0.7).copyWith(
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Float(
                dy: 4,
                ms: 2600,
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [AppColors.primary, AppColors.cyan],
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(p.initials,
                      style: appText(30, w: FontWeight.w800, c: Colors.white)),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 2,
                child: Pressable(
                  scale: 0.85,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 15, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(p.name,
                key: ValueKey(p.name),
                textAlign: TextAlign.center,
                style: appText(20, w: FontWeight.w700, ls: -0.3)),
          ),
          const SizedBox(height: 2),
          Text(p.email, style: appText(12, c: AppColors.onSurfaceVariant)),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(Icons.folder_shared_rounded, 'No. RM ${p.rm}',
                  AppColors.primary),
              _Pill(
                  bpjs ? Icons.verified_rounded : Icons.person_rounded,
                  bpjs ? 'BPJS Kesehatan' : 'Pasien Umum',
                  bpjs ? AppColors.success : AppColors.secondary),
              _Pill(
                  Icons.bloodtype_rounded, 'Gol. ${p.blood}', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: appText(11, w: FontWeight.w700, c: color)),
        ],
      ),
    );
  }
}

// =============================================================================
// Komponen umum
// =============================================================================
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
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
          Text(value,
              style: appText(18, w: FontWeight.w800, c: color, ls: -0.3)),
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

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: glassDecoration(radius: 24, opacity: 0.65),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.multiline = false});

  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          _iconBox(icon, AppColors.primary),
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
                maxLines: multiline ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: appText(12, w: FontWeight.w700, h: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: appText(13, w: FontWeight.w700)),
                Text(sub, style: appText(11, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
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
}

class _NavRow extends StatelessWidget {
  const _NavRow(this.icon, this.title, this.color, this.onTap);

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: appText(13, w: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Pintasan antrean aktif
// =============================================================================
class _TicketShortcut extends StatelessWidget {
  const _TicketShortcut({required this.t, required this.onTap});

  final QueueTicket t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: glassDecoration(radius: 24, opacity: 0.7).copyWith(
            border: Border.all(color: t.c1.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: t.c1.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Breathe(
                amount: 0.08,
                ms: 1400,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(colors: [t.c1, t.c2]),
                  ),
                  child: Icon(t.icon, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BOOKING AKTIF',
                        style: appText(9,
                            w: FontWeight.w700, c: AppColors.primary, ls: 0.8)),
                    Text('${t.label} • ${t.poli}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(13, w: FontWeight.w700)),
                    Text('${t.dateText}, ${t.time} WIB',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: appText(11, c: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  size: 18, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Kartu BPJS
// =============================================================================
class _BpjsCard extends StatelessWidget {
  const _BpjsCard({required this.number, required this.onCopy});

  final String number;
  final VoidCallback onCopy;

  String get _spaced {
    final b = StringBuffer();
    for (var i = 0; i < number.length; i++) {
      if (i != 0 && i % 4 == 0) b.write(' ');
      b.write(number[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [AppColors.success, AppColors.cyan],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text('KARTU BPJS KESEHATAN',
                  style: appText(11,
                      w: FontWeight.w700, c: Colors.white, ls: 0.8)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Aktif',
                        style:
                            appText(10, w: FontWeight.w700, c: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Nomor Kartu',
              style: appText(10, c: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(_spaced,
                    style: appText(20,
                        w: FontWeight.w800, c: Colors.white, ls: 1)),
              ),
              Pressable(
                scale: 0.85,
                child: InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.copy_rounded,
                        size: 16, color: Colors.white),
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
// Tombol keluar
// =============================================================================
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap, this.loading = false});

  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      child: Material(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          splashColor: AppColors.error.withValues(alpha: 0.15),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.error,
                    ),
                  )
                else
                  const Icon(Icons.logout_rounded,
                      size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Text(loading ? 'Sedang Keluar...' : 'Keluar dari Akun',
                    style: appText(13, w: FontWeight.w700, c: AppColors.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bottom sheet edit profil — data diri dan informasi medis lengkap.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.profile, required this.data});
  final PatientProfile profile;
  final Map<String, dynamic> data;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final Map<String, TextEditingController> _c = {
    'name': TextEditingController(text: widget.profile.name),
    'phone': TextEditingController(text: widget.profile.phone),
    'email': TextEditingController(text: widget.profile.email),
    'nik': TextEditingController(text: (widget.data['nik'] ?? '').toString()),
    'birth_date': TextEditingController(
        text: (widget.data['birth_date'] ?? '').toString()),
    'address': TextEditingController(text: widget.profile.address),
    'chronic_conditions': TextEditingController(
        text: widget.profile.chronic == 'Tidak ada'
            ? ''
            : widget.profile.chronic),
    'height_cm': TextEditingController(
        text: (widget.data['height_cm'] ?? '').toString()),
    'weight_kg': TextEditingController(
        text: (widget.data['weight_kg'] ?? '').toString()),
    'emergency_contact_name': TextEditingController(
        text: widget.profile.emergencyName == 'Belum diisi'
            ? ''
            : widget.profile.emergencyName),
    'emergency_contact_phone': TextEditingController(
        text: widget.profile.emergencyPhone == 'Belum diisi'
            ? ''
            : widget.profile.emergencyPhone),
    'bpjs_number': TextEditingController(text: widget.profile.bpjs ?? ''),
  };
  String? _gender;
  String? _blood;
  String? _error;
  final List<Map<String, String>> _allergies = [];
  final TextEditingController _allergy = TextEditingController();
  final TextEditingController _allergyNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    final g = widget.profile.gender.toLowerCase();
    _gender = g == 'laki-laki'
        ? 'laki_laki'
        : g == 'perempuan'
            ? 'perempuan'
            : null;
    _blood = const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
            .contains(widget.profile.blood)
        ? widget.profile.blood
        : null;
    for (final item in (widget.data['allergies'] as List? ?? const [])) {
      if (item is Map)
        _allergies.add({
          'allergen': (item['allergen'] ?? '').toString(),
          'note': (item['note'] ?? '').toString()
        });
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    _allergy.dispose();
    _allergyNote.dispose();
    super.dispose();
  }

  Widget _field(String key, String label, IconData icon,
      {TextInputType? type, int lines = 1, String? hint}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: glassDecoration(radius: 18, opacity: 0.85),
      child: TextField(
          controller: _c[key],
          keyboardType: type,
          minLines: lines,
          maxLines: lines,
          style: appText(13),
          decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(icon, size: 20, color: AppColors.outline),
              labelText: label,
              hintText: hint,
              labelStyle: appText(12, c: AppColors.onSurfaceVariant))),
    );
  }

  Widget _choice<T>(
          {required String label,
          required T? value,
          required List<DropdownMenuItem<T>> items,
          required ValueChanged<T?> onChanged}) =>
      Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: glassDecoration(radius: 18, opacity: 0.85),
          child: DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
                border: InputBorder.none,
                labelText: label,
                labelStyle: appText(12, c: AppColors.onSurfaceVariant)),
            style: appText(13),
          ));

  void _save() {
    final name = _c['name']!.text.trim();
    final phone = _c['phone']!.text.trim();
    final email = _c['email']!.text.trim();
    final nik = _c['nik']!.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama lengkap wajib diisi');
      return;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 9) {
      setState(() => _error = 'Nomor HP tidak valid');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Format email tidak valid');
      return;
    }
    if (nik.isNotEmpty && !RegExp(r'^\d{16}$').hasMatch(nik)) {
      setState(() => _error = 'NIK harus terdiri dari 16 angka');
      return;
    }
    final allergies = [..._allergies];
    if (_allergy.text.trim().isNotEmpty)
      allergies.add(
          {'allergen': _allergy.text.trim(), 'note': _allergyNote.text.trim()});
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(<String, dynamic>{
      'full_name': name,
      'phone': phone,
      'email': email,
      'nik': nik,
      'birth_date': _c['birth_date']!.text.trim(),
      'gender': _gender,
      'address': _c['address']!.text.trim(),
      'blood_type': _blood,
      'chronic_conditions': _c['chronic_conditions']!.text.trim(),
      'height_cm': _c['height_cm']!.text.trim(),
      'weight_kg': _c['weight_kg']!.text.trim(),
      'emergency_contact_name': _c['emergency_contact_name']!.text.trim(),
      'emergency_contact_phone': _c['emergency_contact_phone']!.text.trim(),
      'bpjs_number': _c['bpjs_number']!.text.trim(),
      'allergies': allergies,
      'notify_queue': widget.data['notify_queue'] ?? true,
      'notify_medication': widget.data['notify_medication'] ?? true,
      'biometric_lock': widget.data['biometric_lock'] ?? false,
      'language': widget.data['language'] ?? 'id',
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 40,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                const SizedBox(height: 16),
                Text(
                  'Ubah Data Profil',
                  style: appText(18, w: FontWeight.w700, ls: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lengkapi data diri dan informasi medis Anda.',
                  style: appText(11, c: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Text(
                  'DATA DIRI',
                  style: appText(11, w: FontWeight.w800, c: AppColors.primary),
                ),
                const SizedBox(height: 10),
                _field('name', 'Nama lengkap', Icons.person_rounded),
                _field(
                  'phone',
                  'Nomor HP',
                  Icons.phone_rounded,
                  type: TextInputType.phone,
                ),
                _field(
                  'email',
                  'Email',
                  Icons.mail_rounded,
                  type: TextInputType.emailAddress,
                ),
                _field(
                  'nik',
                  'NIK (16 digit)',
                  Icons.badge_outlined,
                  type: TextInputType.number,
                ),
                _field(
                  'birth_date',
                  'Tanggal lahir (YYYY-MM-DD)',
                  Icons.calendar_month_outlined,
                  hint: 'Contoh: 1996-05-14',
                ),
                _choice<String>(
                  label: 'Jenis kelamin',
                  value: _gender,
                  items: const [
                    DropdownMenuItem(
                      value: 'laki_laki',
                      child: Text('Laki-laki'),
                    ),
                    DropdownMenuItem(
                      value: 'perempuan',
                      child: Text('Perempuan'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                _field('address', 'Alamat lengkap', Icons.home_rounded,
                    lines: 2),
                const SizedBox(height: 10),
                Text(
                  'INFORMASI MEDIS',
                  style: appText(11, w: FontWeight.w800, c: AppColors.primary),
                ),
                const SizedBox(height: 10),
                _choice<String>(
                  label: 'Golongan darah',
                  value: _blood,
                  items:
                      const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() => _blood = value),
                ),
                _field(
                  'height_cm',
                  'Tinggi badan (cm)',
                  Icons.height_rounded,
                  type: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  'weight_kg',
                  'Berat badan (kg)',
                  Icons.monitor_weight_outlined,
                  type: const TextInputType.numberWithOptions(decimal: true),
                ),
                _field(
                  'chronic_conditions',
                  'Riwayat penyakit kronis',
                  Icons.medical_information_outlined,
                  lines: 2,
                ),
                _field(
                  'bpjs_number',
                  'Nomor BPJS',
                  Icons.credit_card_rounded,
                  type: TextInputType.number,
                ),
                const SizedBox(height: 10),
                Text(
                  'ALERGI',
                  style: appText(11, w: FontWeight.w800, c: AppColors.primary),
                ),
                const SizedBox(height: 8),
                if (_allergies.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: glassDecoration(radius: 16, opacity: 0.85),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alergi tersimpan',
                          style: appText(11, w: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (var index = 0; index < _allergies.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _allergies[index]['note']!.isEmpty
                                        ? _allergies[index]['allergen']!
                                        : '${_allergies[index]['allergen']} — ${_allergies[index]['note']}',
                                    style: appText(12),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Hapus alergi',
                                  onPressed: () => setState(
                                    () => _allergies.removeAt(index),
                                  ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: AppColors.error,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: glassDecoration(radius: 18, opacity: 0.85),
                  child: Column(
                    children: [
                      TextField(
                        controller: _allergy,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Nama alergi baru',
                          hintText: 'Contoh: Penisilin',
                        ),
                      ),
                      TextField(
                        controller: _allergyNote,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Catatan alergi (opsional)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'KONTAK DARURAT',
                  style: appText(11, w: FontWeight.w800, c: AppColors.primary),
                ),
                const SizedBox(height: 10),
                _field(
                  'emergency_contact_name',
                  'Nama kontak darurat',
                  Icons.contact_phone_rounded,
                ),
                _field(
                  'emergency_contact_phone',
                  'Nomor kontak darurat',
                  Icons.phone_in_talk_rounded,
                  type: TextInputType.phone,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: appText(
                        11,
                        w: FontWeight.w600,
                        c: AppColors.error,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryContainer, AppColors.primary],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _save,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Simpan Perubahan',
                                style: appText(
                                  13,
                                  w: FontWeight.w700,
                                  c: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: appText(
                        12,
                        w: FontWeight.w700,
                        c: AppColors.onSurfaceVariant,
                      ),
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
