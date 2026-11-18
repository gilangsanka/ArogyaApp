import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'register_screen.dart';

/// Halaman masuk. [onLoggedIn] dipanggil setelah login/registrasi berhasil
/// (biasanya membuka halaman utama aplikasi).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final VoidCallback onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      widget.onLoggedIn();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!isValidEmail(email)) {
      setState(
          () => _error = 'Isi email Anda dulu, lalu ketuk "Lupa kata sandi?".');
      return;
    }
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _error = null);
      authSnack(context, 'Tautan reset kata sandi dikirim ke $email');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authMessage(e));
    }
  }

  Future<void> _openRegister() async {
    final ok = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => const RegisterScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (ok == true) widget.onLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    // Tanpa onBack: tombol kembali tidak ditampilkan dan konten berada di
    // tengah layar.
    return AuthScaffold(
      title: 'Selamat',
      highlight: 'Datang',
      subtitle: 'Masuk untuk booking pemeriksaan, memantau antrean,\n'
          'dan mengakses resep serta rekam medis Anda.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
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
                  controller: _password,
                  label: 'Kata sandi',
                  icon: Icons.lock_rounded,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !_loading,
                  onSubmitted: (_) => _login(),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Kata sandi wajib diisi'
                      : null,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _forgot,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Lupa kata sandi?',
                style: appText(12, w: FontWeight.w700, c: AppColors.primary)),
          ),
        ),
        const SizedBox(height: 12),
        AuthErrorBanner(_error),
        AuthButton(
          label: 'Masuk',
          icon: Icons.arrow_forward_rounded,
          loading: _loading,
          onTap: _login,
        ),
        const AuthOrDivider(),
        AuthSecondaryButton(
          label: 'Belum punya akun? Daftar sekarang',
          onTap: _loading ? null : _openRegister,
        ),
      ],
    );
  }
}
