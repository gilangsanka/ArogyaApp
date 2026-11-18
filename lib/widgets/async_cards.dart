// ignore_for_file: unused_import
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'anim.dart';
import 'sub_page.dart';

/// Kartu loading standar untuk layar yang mengambil data dari Supabase.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Kartu error + tombol coba lagi.
class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 30, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: appText(12, c: AppColors.onSurfaceVariant, h: 1.4)),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
