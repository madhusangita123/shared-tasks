import 'package:flutter/material.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';

/// Quick-pick space name suggestions shown on the Create space screen.
class QuickPickChips extends StatelessWidget {
  const QuickPickChips({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  static const options = [
    'House',
    'Kids',
    'Shopping',
    'Personal',
    'Work',
    'Health',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick pick'.toUpperCase(),
          style: styles.label.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Semantics(
                button: true,
                label: option,
                excludeSemantics: true,
                child: Material(
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    side: BorderSide(color: colors.border),
                  ),
                  child: InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
                    ),
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
