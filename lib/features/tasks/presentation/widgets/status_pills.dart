import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// The "Status" selector on [TaskDetailSheet] — issue #10's segmented
/// button restyled as three pills for issue #56. Selecting a pill writes
/// the new status immediately via [updateStatusProvider], with no confirm
/// and no Save button — the sheet has none any more.
///
/// Its own [ConsumerStatefulWidget] with its own [_currentStatus] state, so
/// a tap here only rebuilds this small row rather than the whole sheet.
/// [_currentStatus] is seeded from [initialStatus] and updated
/// optimistically on tap, ahead of the write resolving, mirroring
/// [AssigneePicker]'s `_currentAssigneeUid`/`_lastConfirmedAssigneeUid`
/// rollback-on-error pattern exactly.
class StatusPills extends ConsumerStatefulWidget {
  const StatusPills({
    required this.spaceId,
    required this.taskId,
    required this.initialStatus,
    super.key,
  });

  final String spaceId;
  final String taskId;
  final TaskStatus initialStatus;

  @override
  ConsumerState<StatusPills> createState() => _StatusPillsState();
}

class _StatusPillsState extends ConsumerState<StatusPills> {
  late TaskStatus _currentStatus = widget.initialStatus;

  /// The last status actually confirmed written (or the sheet's opening
  /// value, before any tap) — [_currentStatus] moves optimistically ahead
  /// of the write completing, and the `ref.listen` below rolls it back to
  /// this if that write fails, rather than leaving the highlighted pill
  /// claiming a status that was never saved.
  late TaskStatus _lastConfirmedStatus;

  @override
  void initState() {
    super.initState();
    _lastConfirmedStatus = widget.initialStatus;
  }

  void _onStatusSelected(TaskStatus status) {
    if (status == _currentStatus) return;
    setState(() => _currentStatus = status);
    ref
        .read(updateStatusProvider.notifier)
        .updateStatus(
          spaceId: widget.spaceId,
          taskId: widget.taskId,
          status: status,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    // `ref.watch` (not just the `ref.read` in `_onStatusSelected`) — same
    // "Bad state: Future already completed" race [AssigneePicker] hit and
    // fixed by watching before any tap can reach the notifier.
    final updateState = ref.watch(updateStatusProvider);

    // Same `!isLoading` reasoning as [AssigneePicker]'s own ref.listen — a
    // state carries the previous value forward through `AsyncLoading`, so
    // it has to be excluded before treating a transition as genuinely
    // finished.
    ref.listen<AsyncValue<void>>(updateStatusProvider, (previous, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        setState(() => _currentStatus = _lastConfirmedStatus);
      } else {
        _lastConfirmedStatus = _currentStatus;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STATUS', style: styles.label.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (index, status) in TaskStatus.values.indexed) ...[
              if (index > 0) const SizedBox(width: 6),
              _StatusPill(
                label: switch (status) {
                  TaskStatus.todo => 'To do',
                  TaskStatus.inProgress => 'In progress',
                  TaskStatus.done => 'Done',
                },
                isActive: status == _currentStatus,
                onTap: () => _onStatusSelected(status),
              ),
            ],
          ],
        ),
        if (updateState.hasError) ...[
          const SizedBox(height: 8),
          Text(
            'Could not update status. Try again.',
            style: styles.bodySmall.copyWith(color: colors.danger),
          ),
        ],
      ],
    );
  }
}

/// One pill in [StatusPills].
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? colors.statusActivePillBackground
              : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.radiusFull),
          border: Border.all(color: isActive ? colors.primary : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? colors.statusActivePillText
                : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
