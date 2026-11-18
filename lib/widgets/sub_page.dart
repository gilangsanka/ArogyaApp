import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'anim.dart';

/// Pindah halaman dengan transisi fade + geser halus.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) {
      final c = CurvedAnimation(
          parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
                  .animate(c),
          child: child,
        ),
      );
    },
  ));
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}

String pad2(int n) => n.toString().padLeft(2, '0');

String fmtTime(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

// =============================================================================
// Kerangka halaman: aurora + header (tombol kembali) + daftar konten
// =============================================================================
class SubPage extends StatefulWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.accent = AppColors.primary,
    this.accent2 = AppColors.primaryContainer,
    this.floating,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final Color accent;
  final Color accent2;
  final Widget? floating;

  @override
  State<SubPage> createState() => _SubPageState();
}

class _SubPageState extends State<SubPage> {
  final ScrollController _ctrl = ScrollController();
  final ValueNotifier<double> _scroll = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _scroll.value = _ctrl.hasClients ? math.max(0.0, _ctrl.offset) : 0;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _header() {
    return ValueListenableBuilder<double>(
      valueListenable: _scroll,
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
          Pressable(
            scale: 0.88,
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 20, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [widget.accent, widget.accent2]),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(16, w: FontWeight.w700, ls: -0.3)),
                Text(widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appText(10, c: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: widget.floating,
      body: Stack(
        children: [
          AuroraBackground(scroll: _scroll),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Reveal(dy: -24, child: _header()),
                Expanded(
                  child: ListView(
                    controller: _ctrl,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottom + 56),
                    children: [
                      for (var i = 0; i < widget.children.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Reveal(
                            delay: math.min(i, 8) * 70,
                            dy: 24,
                            child: widget.children[i],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Komponen kecil bersama
// =============================================================================
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glassDecoration(radius: radius, opacity: 0.65),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: appText(10, w: FontWeight.w700, c: color)),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(text, style: appText(15, w: FontWeight.w700)),
    );
  }
}

/// Baris filter horizontal (chip).
class ChipBar extends StatelessWidget {
  const ChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.color = AppColors.primary,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final on = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? color : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? color : Colors.white),
              ),
              child: Text(
                options[i],
                style: appText(12,
                    w: FontWeight.w700,
                    c: on ? Colors.white : AppColors.onSurfaceVariant),
              ),
            ),
          );
        },
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppColors.outline),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: appText(12, c: AppColors.onSurfaceVariant, h: 1.4)),
          ],
        ),
      ),
    );
  }
}
