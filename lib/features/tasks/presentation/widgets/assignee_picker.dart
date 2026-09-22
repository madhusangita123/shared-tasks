import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/home/presentation/widgets/member_avatar.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// The "Assign to" avatar row on [TaskDetailSheet] — issue #9's section,
/// restyled for issue #56. The signed-in user's own avatar is always first
/// ("Assign to me" being the first and most prominent option); every other
/// space member follows in [spaceMembersProvider]'s existing order, and a
/// trailing "None" option unassigns. Tapping any avatar assigns them;
/// tapping the currently-assigned one again unassigns.
///
/// Its own [ConsumerStatefulWidget] with its own [_currentAssigneeUid]
/// state — not a field on [TaskDetailSheet]'s state, and deliberately so:
/// tapping an avatar only needs to rebuild this small row, not the whole
/// sheet. [_currentAssigneeUid] itself is the optimistic-update mechanism —
/// seeded from [initialAssigneeUid] (a one-shot snapshot from when the
/// sheet opened), then updated the instant an avatar is tapped, *before*
/// [assignTaskProvider]'s write resolves.
class AssigneePicker extends ConsumerStatefulWidget {
  const AssigneePicker({
    required this.spaceId,
    required this.taskId,
    required this.initialAssigneeUid,
    super.key,
  });

  final String spaceId;
  final String taskId;
  final String? initialAssigneeUid;

  @override
  ConsumerState<AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends ConsumerState<AssigneePicker> {
  late String? _currentAssigneeUid = widget.initialAssigneeUid;

  /// The last assignee uid actually confirmed written (or the sheet's
  /// opening value, before any tap). [_currentAssigneeUid] moves
  /// optimistically the instant an avatar is tapped, ahead of the write
  /// actually completing; if that write fails, the `ref.listen` below
  /// rolls [_currentAssigneeUid] back to this rather than leaving the
  /// selection ring claiming an assignment that was never actually saved.
  String? _lastConfirmedAssigneeUid;

  @override
  void initState() {
    super.initState();
    _lastConfirmedAssigneeUid = widget.initialAssigneeUid;
  }

  void _onAvatarTapped(String tappedUid) {
    final newAssigneeUid = _currentAssigneeUid == tappedUid ? null : tappedUid;
    _assign(newAssigneeUid);
  }

  void _onNoneTapped() {
    if (_currentAssigneeUid == null) return;
    _assign(null);
  }

  void _assign(String? newAssigneeUid) {
    setState(() => _currentAssigneeUid = newAssigneeUid);
    ref
        .read(assignTaskProvider.notifier)
        .assignTask(
          spaceId: widget.spaceId,
          taskId: widget.taskId,
          assigneeUid: newAssigneeUid,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.id;
    final membersState = ref.watch(spaceMembersProvider(widget.spaceId));
    // `ref.watch` (not just the `ref.read` in `_assign`) — reading an
    // `AutoDisposeAsyncNotifier` for the first time *and* immediately
    // setting its state in the same call (as the first avatar tap does)
    // races the notifier's own lazy-build completion and throws "Bad
    // state: Future already completed". Watching it here first means it's
    // already initialized by the time any tap can reach it. Also drives
    // the inline error text below when a write fails.
    final assignState = ref.watch(assignTaskProvider);

    // Same `!isLoading` reasoning as [StatusPills]'s listener — a state
    // carries the previous value forward through `AsyncLoading`, so it has
    // to be excluded before treating a transition as genuinely finished.
    ref.listen<AsyncValue<void>>(assignTaskProvider, (previous, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        setState(() => _currentAssigneeUid = _lastConfirmedAssigneeUid);
      } else {
        _lastConfirmedAssigneeUid = _currentAssigneeUid;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ASSIGN TO',
          style: styles.label.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 8),
        membersState.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          // Same "enrichment isn't critical" convention as
          // SpaceSettingsScreen — a member-list fetch failure shouldn't
          // block the rest of the sheet (title/notes editing still works).
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (members) {
            // The signed-in user first, regardless of where they'd
            // otherwise fall in the list — "Assign to me" must be the first
            // option.
            final ordered = [
              ...members.where((member) => member.uid == currentUid),
              ...members.where((member) => member.uid != currentUid),
            ];

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final member in ordered) ...[
                    _AssigneeOption(
                      label: member.uid == currentUid
                          ? 'Me'
                          : member.displayName,
                      isSelected: member.uid == _currentAssigneeUid,
                      onTap: () => _onAvatarTapped(member.uid),
                      avatar: MemberAvatarCircle(member: member, size: 40),
                    ),
                    const SizedBox(width: 16),
                  ],
                  _AssigneeOption(
                    label: 'None',
                    isSelected: _currentAssigneeUid == null,
                    onTap: _onNoneTapped,
                    // A muted person outline, not the spec's dashed circle
                    // with a `−`: the dashed treatment was explicitly
                    // rejected on task rows in #55, and this matches
                    // `TaskRow`'s unassigned indicator so "nobody" looks
                    // the same everywhere.
                    avatar: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.border),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 22,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Same inline-error convention as the sheet's own update error text
        // — no modal, just a small message in place.
        if (assignState.hasError) ...[
          const SizedBox(height: 8),
          Text(
            'Could not update assignee. Try again.',
            style: styles.bodySmall.copyWith(color: colors.danger),
          ),
        ],
      ],
    );
  }
}

/// One tappable item in [AssigneePicker] — a 40x40 avatar with its name
/// below, and a 2px [AppColors.primary] ring when it's the current
/// assignee.
class _AssigneeOption extends StatelessWidget {
  const _AssigneeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.avatar,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Always a 2px ring, transparent when unselected — a
                // conditional `null` border would change this item's size
                // on selection and shuffle the whole row sideways.
                border: Border.all(
                  color: isSelected ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: avatar,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              // maxLines: 1 — without it a long display name wraps to a
              // second line instead of truncating, which is what actually
              // caused the overflow reported in issue #9.
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
