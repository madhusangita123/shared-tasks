import 'package:flutter/material.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';

/// One row in [SpaceSettingsScreen]'s Members list — avatar, display name
/// and, for the space owner only, a trailing "owner" label.
///
/// Unlike `AssigneePicker`, the signed-in user is shown by their own
/// [MemberAvatar.displayName] here, not as "Me": this screen is a roster of
/// who is in the space, so every row reads the same way.
class MemberRow extends StatelessWidget {
  const MemberRow({required this.member, required this.isOwner, super.key});

  final MemberAvatar member;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          MemberAvatarCircle(member: member, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName,
              style: styles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (isOwner)
            Text(
              'owner',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}
