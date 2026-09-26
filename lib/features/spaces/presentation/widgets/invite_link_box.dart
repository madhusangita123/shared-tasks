import 'package:flutter/material.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';

/// The read-only display box for a space's invite link on
/// [SpaceSettingsScreen].
///
/// [SelectableText] rather than [Text] so the link can be selected and
/// copied by hand — the Share button is the primary path, but a long-press
/// copy is the fallback when the share sheet isn't what the user wants.
class InviteLinkBox extends StatelessWidget {
  const InviteLinkBox({required this.link, super.key});

  final String link;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      ),
      child: SelectableText(
        link,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
