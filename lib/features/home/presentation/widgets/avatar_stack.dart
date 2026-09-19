import 'package:flutter/material.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';

/// Overlapping avatars (max 3) with a "+N" overflow circle.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.members, this.size = 22});

  final List<MemberAvatar> members;
  final double size;

  static const _maxShown = 3;
  static const _overlap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shown = members.take(_maxShown).toList();
    final extra = members.length - _maxShown;
    final children = <Widget>[
      for (final m in shown) MemberAvatarCircle(member: m, size: size),
      if (extra > 0)
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            border: Border.all(color: colors.border, width: 2),
          ),
          child: Text(
            '+$extra',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          Transform.translate(
            offset: Offset(-_overlap * i, 0),
            child: children[i],
          ),
      ],
    );
  }
}
