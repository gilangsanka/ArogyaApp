import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import 'anim.dart';

/// Pesan error Supabase Auth -> bahasa Indonesia.
String authMessage(Object e) {
  final raw = e is AuthException ? e.message : e.toString();
  final m = raw.toLowerCase();
  if (m.contains('invalid login credentials')) {
    return 'Email atau kata sandi salah.';
  }
  if (m.contains('email not confirmed')) {
    return 'Email belum diverifikasi. Cek kotak masuk Anda.';
  }
  if (m.contains('already registered') ||
      m.contains('already been registered')) {
    return 'Email sudah terdaftar. Silakan masuk.';
  }
  if (m.contains('password should be at least')) {
    return 'Kata sandi minimal 8 karakter.';
  }
  if (m.contains('rate limit') || m.contains('too many')) {
    return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
  }
  if (m.contains('socket') ||
      m.contains('network') ||
      m.contains('failed host')) {
    return 'Tidak ada koneksi internet.';
  }
  return 'Terjadi kesalahan. Silakan coba lagi.';
}

const String _authLogoUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuC3k1xztZLnhXGOvY-dYmkt6hw72FAVsG8ArtQ-sjYssyFyTCfrLG4HBg8x2zKahNu7oAGEYXfmssaa6sxhT5LaLu5yEDoMMEFC5d7SQQLfldqbrb9g33RTr2USfrXUDsavMrn3YB0ngGfj4fKwPgEWG5Hel3MFum7FA8oY1PbrBqU3Z9UqRnEp0DySPCgg2qNZPvkevc7Cgbi6jxyRjwv0yu13WSFkXxmccHMQLmlD_OkQmh0u0mGb';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
bool isValidEmail(String v) => _emailRe.hasMatch(v.trim());

// =============================================================================
// Kerangka halaman autentikasi (latar aurora + logo + kartu kaca)
// =============================================================================
class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.highlight,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  final String title; // teks biasa
  final String highlight; // teks gradien
  final String subtitle;
  final List<Widget> children; // isi kartu

  /// Jika diisi, tombol kembali tampil di kiri atas dan konten mulai dari
  /// atas. Jika null, tidak ada tombol kembali dan konten berada di tengah
  /// layar (tetap bisa di-scroll bila lebih tinggi dari layar/keyboard muncul).
  final VoidCallback? onBack;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _scroll.value =
          _ctrl.hasClients ? _ctrl.offset.clamp(0.0, 1e9).toDouble() : 0.0;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _logo() {
    return Center(
      child: SizedBox(
        width: 156,
        height: 156,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo lembut di belakang logo.
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.20),
                    AppColors.cyan.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
            Float(
              dy: 5,
              ms: 2600,
              child: Image.network(
                _authLogoUrl,
                width: 104,
                height: 104,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [AppColors.primary, AppColors.cyan],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.white, size: 38),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandChip() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('Arogya • Layanan Kesehatan Digital',
                style: appText(10.5, w: FontWeight.w700, c: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  Widget _secureNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.shield_outlined,
                size: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Data kesehatan Anda hanya dapat diakses oleh Anda '
              'dan tenaga medis yang menangani.',
              textAlign: TextAlign.center,
              style: appText(10.5, c: AppColors.onSurfaceVariant, h: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasBack = widget.onBack != null;
    final pad = hasBack
        ? const EdgeInsets.fromLTRB(22, 12, 22, 36)
        : const EdgeInsets.symmetric(horizontal: 22, vertical: 28);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            AuroraBackground(scroll: _scroll),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      controller: _ctrl,
                      physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics()),
                      padding: pad,
                      child: ConstrainedBox(
                        // Tinggi minimum = tinggi layar, supaya konten bisa
                        // dipusatkan secara vertikal.
                        constraints: BoxConstraints(
                          minHeight: (box.maxHeight - pad.vertical)
                              .clamp(0.0, double.infinity)
                              .toDouble(),
                        ),
                        child: Column(
                          mainAxisAlignment: hasBack
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasBack) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Pressable(
                                  scale: 0.88,
                                  child: InkWell(
                                    onTap: widget.onBack,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white),
                                      ),
                                      child: const Icon(
                                          Icons.arrow_back_rounded,
                                          size: 20,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            Reveal(dy: 20, scaleFrom: 0.8, child: _logo()),
                            const SizedBox(height: 18),
                            Reveal(delay: 80, dy: 12, child: _brandChip()),
                            const SizedBox(height: 16),
                            Reveal(
                              delay: 120,
                              dy: 16,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${widget.title} ',
                                      style: appText(28,
                                          w: FontWeight.w800, ls: -0.6)),
                                  FlowText(widget.highlight,
                                      style: appText(28,
                                          w: FontWeight.w800, ls: -0.6)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Reveal(
                              delay: 180,
                              dy: 12,
                              child: Text(widget.subtitle,
                                  textAlign: TextAlign.center,
                                  style: appText(12.5,
                                      c: AppColors.onSurfaceVariant, h: 1.55)),
                            ),
                            const SizedBox(height: 28),
                            Reveal(
                              delay: 240,
                              dy: 30,
                              scaleFrom: 0.97,
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 26, 22, 22),
                                decoration:
                                    glassDecoration(radius: 32, opacity: 0.72)
                                        .copyWith(
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryContainer
                                          .withValues(alpha: 0.18),
                                      blurRadius: 34,
                                      offset: const Offset(0, 14),
                                    ),
                                    BoxShadow(
                                      color: AppColors.cyan
                                          .withValues(alpha: 0.08),
                                      blurRadius: 40,
                                      offset: const Offset(-8, -4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: widget.children,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Reveal(delay: 320, dy: 10, child: _secureNote()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Kolom input
// =============================================================================
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.isPassword = false,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.bottomGap = 14,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  /// Jarak di bawah kolom.
  final double bottomGap;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hide = true;
  bool _focused = false;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(bottom: widget.bottomGap),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: glassDecoration(radius: 20, opacity: 0.92).copyWith(
        border: Border.all(
          color: _focused
              ? AppColors.primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.9),
          width: _focused ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.primaryContainer.withValues(alpha: 0.05),
            blurRadius: _focused ? 18 : 10,
            offset: Offset(0, _focused ? 6 : 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        enabled: widget.enabled,
        obscureText: widget.isPassword && _hide,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        autofillHints: widget.autofillHints,
        autocorrect: !widget.isPassword,
        enableSuggestions: !widget.isPassword,
        cursorColor: AppColors.primary,
        style: appText(13.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.icon,
              key: ValueKey(_focused),
              size: 20,
              color: _focused ? AppColors.primary : AppColors.outline,
            ),
          ),
          labelText: widget.label,
          labelStyle: appText(12, c: AppColors.onSurfaceVariant),
          floatingLabelStyle:
              appText(12, w: FontWeight.w700, c: AppColors.primary),
          errorStyle: appText(10.5, w: FontWeight.w600, c: AppColors.error),
          suffixIcon: widget.isPassword
              ? IconButton(
                  splashRadius: 18,
                  onPressed: () => setState(() => _hide = !_hide),
                  icon: Icon(
                    _hide
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 19,
                    color: AppColors.outline,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// =============================================================================
// Tombol utama (gradien) + status loading
// =============================================================================
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
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
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.96,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [AppColors.primaryContainer, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: loading ? null : onTap,
            splashColor: Colors.white.withValues(alpha: 0.3),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('load'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label,
                              style: appText(14,
                                  w: FontWeight.w700, c: Colors.white)),
                          const SizedBox(width: 10),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                            child: Icon(icon, size: 15, color: Colors.white),
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

/// Tombol sekunder (garis tepi) untuk aksi pendamping, mis. "Buat akun baru".
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.97,
      child: Material(
        color: Colors.white.withValues(alpha: 0.6),
        shape: StadiumBorder(
          side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.35), width: 1.3),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(label,
                  style: appText(13, w: FontWeight.w700, c: AppColors.primary)),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Banner error dari server (muncul dengan animasi)
// =============================================================================
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(message!,
                        style: appText(11.5,
                            w: FontWeight.w600, c: AppColors.error, h: 1.35)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Garis pemisah "atau".
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
          height: 1, color: AppColors.outline.withValues(alpha: 0.25)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child:
                Text('atau', style: appText(11, c: AppColors.onSurfaceVariant)),
          ),
          line,
        ],
      ),
    );
  }
}

void authSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
    ));
}
