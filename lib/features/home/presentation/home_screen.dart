import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_spacing.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/presentation/providers/home_provider.dart';
import 'package:shared_tasks/features/home/presentation/widgets/empty_spaces_state.dart';
import 'package:shared_tasks/features/home/presentation/widgets/space_card.dart';

/// S-02 — Home screen. Lists every space the user is a member of, ordered by
/// most recently updated (sorted by [userSpacesProvider]'s query).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacesState = ref.watch(userSpacesProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(spaces: spacesState.asData?.value),
            Expanded(
              child: spacesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Something went wrong loading your spaces.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (spaces) {
                  if (spaces.isEmpty) return const EmptySpacesState();
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      88,
                    ),
                    itemCount: spaces.length,
                    itemBuilder: (context, i) => SpaceCard(space: spaces[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Tooltip(
        message: 'Create space',
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.3),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // push, not go, so back returns to Home.
              onTap: () => context.push(AppRoutes.createSpace),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.spaces});

  final List<HomeSpace>? spaces;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = AppTextStyles.of(context);
    final list = spaces ?? const <HomeSpace>[];
    final open = list.fold<int>(0, (sum, s) => sum + s.openTaskCount);
    final n = list.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xl,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My spaces',
                  style: text.headingLarge.copyWith(color: colors.textPrimary),
                ),
                Text(
                  '$n ${n == 1 ? 'space' : 'spaces'} · '
                  '$open open ${open == 1 ? 'task' : 'tasks'}',
                  style: text.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            // push, not go, so back returns to Home.
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}
