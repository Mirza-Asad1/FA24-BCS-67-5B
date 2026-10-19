import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Floating animated placeholder shown when there are no patients.
class EmptyState extends StatefulWidget {
  final String title;
  final String subtitle;
  const EmptyState({super.key, required this.title, required this.subtitle});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, -12 * Curves.easeInOut.transform(_c.value)),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withOpacity(0.18),
                    AppColors.accent.withOpacity(0.18),
                  ]),
                ),
                child: const Icon(Icons.medical_services_rounded,
                    size: 64, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}
