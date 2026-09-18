import 'package:flutter/material.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';

/// App mark for S-01 — a 64x64 rounded square in [AppColors.primary]
/// containing three horizontal white lines simulating a checklist.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _line(color: Colors.white),
          const SizedBox(height: 5),
          _line(color: Colors.white.withValues(alpha: 0.6), widthFactor: 0.65),
          const SizedBox(height: 5),
          _line(color: Colors.white),
        ],
      ),
    );
  }

  Widget _line({required Color color, double widthFactor = 1}) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
