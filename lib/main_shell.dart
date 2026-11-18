import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'screen/home_screen.dart';
import 'screen/booking_screen.dart';
import 'screen/antrean_screen.dart';
import 'screen/profile_screen.dart';

/// Kerangka aplikasi pasien dengan navigasi utama:
/// Beranda · Booking · Antrean · Profil.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  BookingPreset? _preset;

  /// Tiket antrean aktif.
  QueueTicket? _ticket;

  void _go(int i) => setState(() => _index = i);

  /// Dipanggil tombol "Booking" di kartu dokter beranda:
  /// buka tab Booking dengan poli & dokter sudah terpilih.
  void _bookDoctor(int poli, int doc) => setState(() {
        _preset = BookingPreset(poli, doc);
        _index = 1;
      });

  /// Dipanggil BookingScreen saat booking berhasil dikonfirmasi.
  void _onBooked(QueueTicket t) => setState(() => _ticket = t);

  /// Dipanggil AntreanScreen saat pasien membatalkan booking.
  void _onCancelTicket() => setState(() => _ticket = null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(onNavigate: _go, onBookDoctor: _bookDoctor),
              BookingScreen(
                onNavigate: _go,
                preset: _preset,
                onBooked: _onBooked,
              ),
              QueueScreen(
                onNavigate: _go,
                ticket: _ticket,
                onCancel: _onCancelTicket,
              ),
              ProfileScreen(
                onNavigate: _go,
                ticket: _ticket,
              ),
            ],
          ),
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: _NavBar(index: _index, onTap: _go),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, String)>[
    (Icons.home_rounded, 'Beranda'),
    (Icons.edit_calendar_rounded, 'Booking'),
    (Icons.confirmation_number_rounded, 'Antrean'),
    (Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer.withValues(alpha: 0.18),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              flex: i == index ? 3 : 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: i == index
                        ? const LinearGradient(colors: [
                            AppColors.primaryContainer,
                            AppColors.primary
                          ])
                        : null,
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: AppColors.primaryContainer
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _items[i].$1,
                        size: 21,
                        color: i == index
                            ? Colors.white
                            : AppColors.onSurfaceVariant,
                      ),
                      if (i == index) ...[
                        const SizedBox(width: 6),
                        Text(_items[i].$2,
                            style: appText(12,
                                w: FontWeight.w700, c: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


