import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';

/// Shown when the user has no spaces yet.
class EmptySpacesState extends StatelessWidget {
  const EmptySpacesState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = AppTextStyles.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.3,
              child: Icon(
                Icons.checklist_rounded,
                size: 40,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No spaces yet',
              style: text.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first space to get started',
              style: text.bodySmall.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push(AppRoutes.createSpace),
                child: const Text('Create space'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
