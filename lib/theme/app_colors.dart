import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna KlinikCare (sama dengan konfigurasi Tailwind pada desain HTML).
class AppColors {
  static const surface = Color(0xFFF8F9FE);
  static const primary = Color(0xFF5341CD);
  static const primaryContainer = Color(0xFF6C5CE7);
  static const primaryFixed = Color(0xFFE4DFFF);
  static const secondary = Color(0xFF006A67);
  static const secondaryContainer = Color(0xFF5AF9F3);
  static const tertiary = Color(0xFF544DAA);
  static const tertiaryContainer = Color(0xFF6D66C4);
  static const textMain = Color(0xFF1F1E2E);
  static const onSurfaceVariant = Color(0xFF5A5869);
  static const outline = Color(0xFF787586);
  static const success = Color(0xFF00B894);
  static const warning = Color(0xFFE1A93B);
  static const error = Color(0xFFFF7675);
  static const cyan = Color(0xFF00CEC9);
}

/// Style teks Plus Jakarta Sans.
TextStyle appText(
  double size, {
  FontWeight w = FontWeight.w500,
  Color c = AppColors.textMain,
  double? h,
  double? ls,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
    );

/// Dekorasi kartu kaca (glassmorphism ringan).
BoxDecoration glassDecoration({double radius = 24, double opacity = 0.7}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
    boxShadow: [
      BoxShadow(
        color: AppColors.primaryContainer.withValues(alpha: 0.08),
        blurRadius: 30,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Teks dengan gradien ungu → cyan.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.primary, AppColors.cyan],
      ).createShader(rect),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
