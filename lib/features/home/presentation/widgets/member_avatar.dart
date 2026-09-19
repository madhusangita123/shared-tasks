import 'package:flutter/material.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';

/// Circular member avatar: photo if present, otherwise coloured initial.
class MemberAvatarCircle extends StatelessWidget {
  const MemberAvatarCircle({super.key, required this.member, this.size = 22});

  final MemberAvatar member;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final photo = member.photoUrl;
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initial = member.displayName.isEmpty
        ? '?'
        : member.displayName[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.avatarSet(member.uid),
        border: Border.all(color: colors.background, width: 2),
        image: hasPhoto
            ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      child: hasPhoto
          ? null
          : Text(
              initial,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}
