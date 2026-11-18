import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main_shell.dart';
import 'screen/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kunci orientasi ke potret (sesuai desain mobile).
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Supabase.initialize(
    url: 'https://kislhwelkjxpxuompfbu.supabase.co',
    anonKey: 'sb_publishable_sGF0J5cop-n8bp8Yk5dRiw_rHRv3eR_',
  );

  runApp(const KlinikCareApp());
}

class KlinikCareApp extends StatelessWidget {
  const KlinikCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF5341CD);

    return MaterialApp(
      title: 'KlinikCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: const Color(0xFF006A67),
          surface: const Color(0xFFF8F9FE),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: const SplashRoute(),
    );
  }
}

/// Membungkus SplashScreen. [onStart] dipanggil setelah pengguna berhasil
/// login/daftar (atau langsung bila sesi masih tersimpan), lalu membuka
/// MainShell dan menghapus splash + login dari tumpukan halaman.
class SplashRoute extends StatelessWidget {
  const SplashRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      onStart: () {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 450),
            pageBuilder: (_, __, ___) => const MainShell(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
          (route) => false,
        );
      },
    );
  }
}
