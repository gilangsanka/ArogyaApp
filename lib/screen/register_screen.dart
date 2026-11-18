import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// Halaman pendaftaran akun pasien.
/// Pop dengan `true` bila akun langsung aktif (sesi terbuka), sehingga
/// LoginScreen melanjutkan ke halaman utama. Pop dengan `false` bila perlu
/// verifikasi email lebih dulu.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _agree = false;
  bool _agreeError = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    final valid = _form.currentState!.validate();
    if (!_agree) setState(() => _agreeError = true);
    if (!valid || !_agree) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        // full_name dibaca trigger handle_new_user di database.
        data: {
          'full_name': _name.text.trim(),
          'phone': _phone.text.trim(),
        },
      );
      if (!mounted) return;

      if (res.session != null) {
        // Konfirmasi email dimatikan -> langsung masuk.
        Navigator.of(context).pop(true);
      } else {
        await _showVerifyDialog(_email.text.trim());
        if (!mounted) return;
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showVerifyDialog(String email) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.success.withValues(alpha: 0.14),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: AppColors.success, size: 28),
        ),
        title: Text('Cek email Anda',
            textAlign: TextAlign.center,
            style: appText(17, w: FontWeight.w700)),
        content: Text(
          'Kami mengirim tautan verifikasi ke\n$email.\n'
          'Verifikasi dulu, lalu masuk dengan akun Anda.',
          textAlign: TextAlign.center,
          style: appText(12.5, c: AppColors.onSurfaceVariant, h: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Ke halaman masuk',
                style: appText(12.5, w: FontWeight.w700, c: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tanpa onBack: tombol kembali tidak ditampilkan dan konten berada di
    // tengah layar. Jalan kembali ke halaman masuk lewat tautan "Masuk".
    return AuthScaffold(
      title: 'Buat',
      highlight: 'Akun Baru',
      subtitle: 'Daftar untuk mendapatkan nomor rekam medis\n'
          'dan layanan antrean digital.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                AuthField(
                  controller: _name,
                  label: 'Nama lengkap',
                  icon: Icons.person_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !_loading,
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Nama minimal 3 karakter'
                      : null,
                ),
                AuthField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.mail_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  enabled: !_loading,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!isValidEmail(v)) return 'Format email tidak valid';
                    return null;
                  },
                ),
                AuthField(
                  controller: _phone,
                  label: 'No. HP',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  enabled: !_loading,
                  validator: (v) {
                    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (d.length < 9 || d.length > 15) {
                      return 'Nomor HP tidak valid';
                    }
                    return null;
                  },
                ),
                AuthField(
                  controller: _password,
                  label: 'Kata sandi (min. 8 karakter)',
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  enabled: !_loading,
                  bottomGap: 8,
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Minimal 8 karakter';
                    if (!RegExp(r'[A-Za-z]').hasMatch(v) ||
                        !RegExp(r'\d').hasMatch(v)) {
                      return 'Gunakan kombinasi huruf dan angka';
                    }
                    return null;
                  },
                ),
                _PasswordStrength(_password),
                AuthField(
                  controller: _confirm,
                  label: 'Ulangi kata sandi',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  enabled: !_loading,
                  onSubmitted: (_) => _register(),
                  validator: (v) =>
                      v != _password.text ? 'Kata sandi tidak sama' : null,
                ),
              ],
            ),
          ),
        ),
        // Persetujuan
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _loading
              ? null
              : () => setState(() {
                    _agree = !_agree;
                    if (_agree) _agreeError = false;
                  }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agree,
                    activeColor: AppColors.primary,
                    side: BorderSide(
                        color:
                            _agreeError ? AppColors.error : AppColors.outline,
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    onChanged: _loading
                        ? null
                        : (v) => setState(() {
                              _agree = v ?? false;
                              if (_agree) _agreeError = false;
                            }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saya menyetujui Syarat & Ketentuan dan Kebijakan Privasi, '
                    'termasuk pengelolaan data kesehatan saya.',
                    style: appText(11,
                        c: _agreeError
                            ? AppColors.error
                            : AppColors.onSurfaceVariant,
                        h: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AuthErrorBanner(_error),
        AuthButton(
          label: 'Daftar',
          icon: Icons.check_rounded,
          loading: _loading,
          onTap: _register,
        ),
        const AuthOrDivider(),
        AuthSecondaryButton(
          label: 'Sudah punya akun? Masuk',
          onTap: _loading ? null : () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

/// Indikator kekuatan kata sandi (3 segmen) di bawah kolom kata sandi.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength(this.controller);

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final p = value.text;
        if (p.isEmpty) {
          return const SizedBox(height: 6, width: double.infinity);
        }
        var score = 0;
        if (p.length >= 8) score++;
        if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) {
          score++;
        }
        if (p.length >= 12 ||
            (RegExp(r'[A-Z]').hasMatch(p) &&
                RegExp(r'[^A-Za-z0-9]').hasMatch(p))) {
          score++;
        }
        final level = score < 1 ? 1 : score;
        final color = level == 1
            ? AppColors.error
            : (level == 2 ? AppColors.warning : AppColors.success);
        final label = level == 1 ? 'Lemah' : (level == 2 ? 'Sedang' : 'Kuat');
        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: i < level
                          ? color
                          : AppColors.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Text(label, style: appText(10.5, w: FontWeight.w700, c: color)),
            ],
          ),
        );
      },
    );
  }
}
