import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// One task row on [TaskListScreen] — issue #55's flat restyle of the
/// former private `_TaskRow` card. A borderless row (title + assignee
/// avatar + three-dot menu) separated from its neighbours by a 1px rule
/// rather than by [Card] margins, which is what makes a long list read as
/// one continuous list instead of a stack of tiles.
///
/// Behaviour is deliberately unchanged from the card version: the leading
/// status icon is still its own independently-tappable target (issue #10)
/// that cycles todo → in_progress → done → todo one step per tap, separate
/// from the row's own [onTap]; the three-dot menu still carries all four
/// items (Edit / Remove / Assign / Mark done) with their original values.
/// Only the colours, spacing and the dropped notes subtitle changed —
/// notes now live solely in the detail sheet.
///
/// A [ConsumerWidget] (not [StatelessWidget]) — needs [spaceMembersProvider]
/// to resolve [Task.assigneeUid] into a displayable avatar.
class TaskRow extends ConsumerWidget {
  const TaskRow({
    required this.task,
    required this.spaceId,
    required this.onTap,
    required this.onMenuSelected,
    required this.isLast,
    super.key,
  });

  final Task task;
  final String spaceId;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  /// Suppresses this row's bottom rule, so the list doesn't end on a
  /// dangling separator.
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final isDone = task.status == TaskStatus.done;
    final membersState = ref.watch(spaceMembersProvider(spaceId));
    // whereType, not firstWhere — a member who's left the space (or an
    // enrichment fetch failure, see spaceMembersProvider's own "skip
    // silently" convention) means no match, which is exactly the
    // "Unassigned" neutral state, not an error.
    final assignee = task.assigneeUid == null
        ? null
        : membersState.valueOrNull
              ?.where((member) => member.uid == task.assigneeUid)
              .firstOrNull;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: [
            _StatusIcon(
              status: task.status,
              onTap: () => ref
                  .read(updateStatusProvider.notifier)
                  .updateStatus(
                    spaceId: spaceId,
                    taskId: task.id,
                    status: task.status.next,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: styles.bodyMedium.copyWith(
                  color: isDone ? colors.textMuted : colors.textPrimary,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: isDone ? colors.textMuted : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _AssigneeIndicator(assignee: assignee),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: colors.textMuted),
              color: colors.surfaceElevated,
              onSelected: onMenuSelected,
              itemBuilder: (context) => [
                _menuItem(
                  value: 'edit',
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: colors.textPrimary,
                  styles: styles,
                ),
                _menuItem(
                  value: 'remove',
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  color: colors.danger,
                  styles: styles,
                ),
                _menuItem(
                  value: 'assign',
                  icon: Icons.person_add_outlined,
                  label: 'Assign',
                  color: colors.textPrimary,
                  styles: styles,
                ),
                _menuItem(
                  value: 'mark_done',
                  icon: Icons.done_outlined,
                  label: 'Mark done',
                  color: colors.textPrimary,
                  styles: styles,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
    required AppTextStyles styles,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: styles.bodyMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// The leading status icon on a task row — issue #10, restyled for #55. Its
/// own tappable target, deliberately separate from the row's own `onTap`
/// (which opens the detail sheet) so tapping it doesn't also open the
/// sheet. Tapping cycles [TaskStatus.next] — todo → in_progress → done →
/// todo.
///
/// Icon and colour both vary by status, now via the design system's own
/// tokens: `textMuted` for todo (an inert, unstarted ring), `warning` for
/// in_progress (in flight, deliberately not an error colour) and `success`
/// for done.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.onTap});

  final TaskStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (icon, color) = switch (status) {
      TaskStatus.todo => (Icons.radio_button_unchecked, colors.textMuted),
      TaskStatus.inProgress => (Icons.timelapse, colors.warning),
      TaskStatus.done => (Icons.check_circle, colors.success),
    };

    return Tooltip(
      message: switch (status) {
        TaskStatus.todo => 'Todo — tap to start',
        TaskStatus.inProgress => 'In progress — tap to mark done',
        TaskStatus.done => 'Done — tap to reopen',
      },
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

/// The assignee indicator on a task row — issue #9, restyled for #55.
/// Reuses the home screen's [MemberAvatarCircle] when somebody's assigned,
/// so a person looks identical everywhere in the app.
///
/// Unassigned keeps issue #9's neutral person outline rather than #55's
/// specified dashed `?` ring — the `?` read as a question being asked of
/// the user. Deliberately muted either way: "unassigned" is an empty slot,
/// never a warning state.
class _AssigneeIndicator extends StatelessWidget {
  const _AssigneeIndicator({required this.assignee});

  final MemberAvatar? assignee;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final member = assignee;

    if (member != null) {
      return Tooltip(
        message: member.displayName,
        child: MemberAvatarCircle(member: member, size: 22),
      );
    }

    return Tooltip(
      message: 'Unassigned',
      child: SizedBox(
        width: 22,
        height: 22,
        child: Icon(Icons.person_outline, size: 20, color: colors.textMuted),
      ),
    );
  }
}
