import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/presentation/widgets/avatar_stack.dart';

/// One space in the home list.
class SpaceCard extends StatelessWidget {
  const SpaceCard({super.key, required this.space});

  final HomeSpace space;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = AppTextStyles.of(context);
    final n = space.openTaskCount;
    final radius = BorderRadius.circular(AppRadius.radiusMd);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // push, not go, so back returns to Home.
          onTap: () => context.push(AppRoutes.taskListPath(space.id)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    space.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      n == 0
                          ? 'No open tasks'
                          : '$n open ${n == 1 ? 'task' : 'tasks'}',
                      style: text.caption.copyWith(color: colors.textSecondary),
                    ),
                    if (space.memberAvatars.isNotEmpty)
                      AvatarStack(members: space.memberAvatars),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
