import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/core/widgets/app_text_field.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// S-04 — Task detail sheet. Shown via `showModalBottomSheet` for both
/// adding a new task (`task == null`) and editing an existing one
/// (`task` supplied).
///
/// In edit mode only, also shows an "Assign to" section (issue #9) — a
/// space member avatar row, the signed-in user's own avatar first and
/// largest ("assign to me"), tapping any avatar assigns them and tapping
/// the currently-assigned one again unassigns. Not shown in add mode: an
/// unsaved task has no id in Firestore yet to assign. That section is its
/// own [_AssignToSection] widget with its own state (not a field on this
/// sheet's state) specifically so tapping an avatar only rebuilds that
/// small subtree — folding it into this State would `setState` the whole
/// sheet on every tap, visibly re-laying-out the Title/Notes fields and
/// Save button for no reason.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for the [TextEditingController]s and inline validation error
/// text, the same reasoning [CreateSpaceScreen] needed `StatefulWidget`
/// for.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({required this.spaceId, super.key, this.task});

  final String spaceId;
  final Task? task;

  bool get isEditing => task != null;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late final _titleController = TextEditingController(text: widget.task?.title);
  late final _notesController = TextEditingController(text: widget.task?.notes);

  /// Inline validation error text. Stays `null` until the user has
  /// attempted submit — a pristine empty field shows no error.
  String? _validationError;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Validates the current title. Returns `true` if valid; otherwise sets
  /// [_validationError] and returns `false`.
  bool _validate() {
    final trimmed = _titleController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _validationError = 'Title is required');
      return false;
    }
    if (trimmed.length > AppConstants.taskTitleMaxLength) {
      setState(
        () => _validationError =
            'Title must be ${AppConstants.taskTitleMaxLength} characters or fewer',
      );
      return false;
    }
    setState(() => _validationError = null);
    return true;
  }

  void _onSubmitPressed() {
    // Dismiss the keyboard before submitting — otherwise, on some devices,
    // the same tap that hits Save also has to fight the keyboard closing
    // and the sheet's layout reflowing back to its non-keyboard height in
    // the same frame, which can make the tap land somewhere unintended.
    FocusScope.of(context).unfocus();

    if (!_validate()) return;

    final trimmedTitle = _titleController.text.trim();
    final trimmedNotes = _notesController.text.trim();
    final notes = trimmedNotes.isEmpty ? null : trimmedNotes;

    if (widget.isEditing) {
      ref
          .read(updateTaskProvider.notifier)
          .updateTask(
            spaceId: widget.spaceId,
            taskId: widget.task!.id,
            title: trimmedTitle,
            notes: notes,
          );
    } else {
      ref
          .read(addTaskProvider.notifier)
          .addTask(spaceId: widget.spaceId, title: trimmedTitle, notes: notes);
    }
  }

  /// Same no-modal inline-error convention as [CreateSpaceScreen]'s
  /// `_errorMessage` — duplicated here since it's not shared.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return widget.isEditing
        ? 'Could not save task. Try again.'
        : 'Could not add task. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final controllerProvider = widget.isEditing
        ? updateTaskProvider
        : addTaskProvider;

    ref.listen<AsyncValue<void>>(controllerProvider, (previous, next) {
      // Not `next.hasValue && !next.hasError` — [AsyncNotifier]'s `state=`
      // setter carries the previous value forward through `AsyncLoading`
      // (and `AsyncError`) so `isLoading`/error UI elsewhere can still show
      // stale data, which means `hasValue` is also true *while still
      // loading*, right after the previous state was `AsyncData`. That
      // matched this check and popped the sheet the instant Save was
      // tapped — before the write even reached Firestore, silently
      // skipping the loading spinner and swallowing any failure (the
      // sheet was already gone by the time an error could show). Excluding
      // `isLoading` is what actually waits for a real result.
      if (!next.isLoading && next.hasValue && !next.hasError) {
        Navigator.of(context).pop();
      }
    });

    final submitState = ref.watch(controllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          // SingleChildScrollView — the "Assign to" section (issue #9)
          // made this sheet tall enough that it could overflow when the
          // keyboard is open and shrinks the available height; a plain
          // fixed Column had nowhere for the extra content to go. This
          // makes the sheet scroll instead of overflowing, with no visual
          // change when everything already fits.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text(
                widget.isEditing ? 'Edit task' : 'Add task',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Title',
                controller: _titleController,
                // Only for a brand-new task — the user is about to type a
                // title, so the keyboard opening immediately is helpful.
                // Editing an existing task already has a title; popping the
                // keyboard open over it (when the user more likely came to
                // change the assignee or notes) is just in the way.
                autofocus: !widget.isEditing,
                maxLength: AppConstants.taskTitleMaxLength,
                errorText: _validationError,
              ),
              // Only in edit mode — a new, unsaved task has no id in
              // Firestore yet to assign (see class doc comment). Between
              // Title and Notes, not after Notes — reads as part of the
              // task's current identity (what it's called, who's on it)
              // rather than trailing detail.
              if (widget.isEditing) ...[
                const SizedBox(height: 16),
                Text('Assign to', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _AssignToSection(
                  spaceId: widget.spaceId,
                  taskId: widget.task!.id,
                  initialAssigneeUid: widget.task!.assigneeUid,
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 16),
                Text('Status', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _StatusSection(
                  spaceId: widget.spaceId,
                  taskId: widget.task!.id,
                  initialStatus: widget.task!.status,
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: 'Notes',
                controller: _notesController,
                maxLines: 3,
                maxLength: AppConstants.taskNotesMaxLength,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: widget.isEditing ? 'Save' : 'Add',
                isLoading: submitState.isLoading,
                onPressed: _onSubmitPressed,
              ),
              if (submitState.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage(submitState.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Assign to" avatar row — issue #9. The signed-in user's own avatar
/// is always first and visually larger ("Assign to me" being "the first
/// and most prominent option"); every other space member follows in
/// [spaceMembersProvider]'s existing order. Tapping any avatar assigns
/// them; tapping the currently-assigned one again unassigns.
///
/// Its own [ConsumerStatefulWidget] with its own [_currentAssigneeUid]
/// state — not a field on [TaskDetailSheet]'s state, and deliberately so:
/// tapping an avatar only needs to rebuild this small row, not the whole
/// sheet (Title/Notes fields, Save button) the way folding this state into
/// the parent would force on every tap. [_currentAssigneeUid] itself is
/// the actual optimistic-update mechanism the AC asks for — seeded from
/// [initialAssigneeUid] (a one-shot snapshot from when the sheet opened),
/// then updated the instant an avatar is tapped, *before*
/// [assignTaskProvider]'s write resolves.
class _AssignToSection extends ConsumerStatefulWidget {
  const _AssignToSection({
    required this.spaceId,
    required this.taskId,
    required this.initialAssigneeUid,
  });

  final String spaceId;
  final String taskId;
  final String? initialAssigneeUid;

  @override
  ConsumerState<_AssignToSection> createState() => _AssignToSectionState();
}

class _AssignToSectionState extends ConsumerState<_AssignToSection> {
  late String? _currentAssigneeUid = widget.initialAssigneeUid;

  /// The last assignee uid actually confirmed written (or the sheet's
  /// opening value, before any tap). [_currentAssigneeUid] moves
  /// optimistically the instant an avatar is tapped, ahead of the write
  /// actually completing; if that write fails, the `ref.listen` below
  /// rolls [_currentAssigneeUid] back to this rather than leaving the
  /// selection ring/"Unassigned" text claiming an assignment that was
  /// never actually saved.
  String? _lastConfirmedAssigneeUid;

  @override
  void initState() {
    super.initState();
    _lastConfirmedAssigneeUid = widget.initialAssigneeUid;
  }

  void _onAvatarTapped(String tappedUid) {
    final newAssigneeUid = _currentAssigneeUid == tappedUid ? null : tappedUid;
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
    final currentUid = ref.watch(authStateProvider).valueOrNull?.id;
    final membersState = ref.watch(spaceMembersProvider(widget.spaceId));
    // `ref.watch` (not just the `ref.read` in `_onAvatarTapped`) — reading
    // an `AutoDisposeAsyncNotifier` for the first time *and* immediately
    // setting its state in the same call (as the first avatar tap does)
    // races the notifier's own lazy-build completion and throws "Bad
    // state: Future already completed". Watching it here first means it's
    // already initialized by the time any tap can reach it. Also drives
    // the inline error text below when a write fails.
    final assignState = ref.watch(assignTaskProvider);

    // Same `!isLoading` reasoning as the sheet's own Save-navigation
    // listener — a state carries the previous value forward through
    // `AsyncLoading`, so it has to be excluded before treating a
    // transition as genuinely finished.
    ref.listen<AsyncValue<void>>(assignTaskProvider, (previous, next) {
      if (next.isLoading) return;
      if (next.hasError) {
        setState(() => _currentAssigneeUid = _lastConfirmedAssigneeUid);
      } else {
        _lastConfirmedAssigneeUid = _currentAssigneeUid;
      }
    });

    return membersState.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      // Same "enrichment isn't critical" convention as SpaceSettingsScreen
      // — a member-list fetch failure shouldn't block the rest of the
      // sheet (title/notes editing still works).
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (members) {
        // The signed-in user first, regardless of where they'd otherwise
        // fall in the list — "Assign to me" must be the first option.
        final ordered = [
          ...members.where((member) => member.uid == currentUid),
          ...members.where((member) => member.uid != currentUid),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              // Tall enough for the largest case: "Me"'s 28px-radius
              // avatar (56 diameter) + its 2px padding + 2px selection
              // ring on every side (+8) + the gap + a label line — 76px
              // was too tight and clipped/overflowed exactly that case.
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ordered.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final member = ordered[index];
                  final isMe = member.uid == currentUid;
                  return _AssigneeAvatar(
                    member: member,
                    isMe: isMe,
                    isSelected: member.uid == _currentAssigneeUid,
                    onTap: () => _onAvatarTapped(member.uid),
                  );
                },
              ),
            ),
            if (_currentAssigneeUid == null) ...[
              const SizedBox(height: 8),
              Text(
                'Unassigned',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Same inline-error convention as the sheet's own Save/Add
            // error text below — no modal, just a small message in place.
            if (assignState.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'Could not update assignee. Try again.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The "Status" selector — issue #10. A [SegmentedButton] with Todo /
/// In Progress / Done segments, showing the task's current status
/// selected. Selecting a different segment writes it immediately via
/// [updateStatusProvider] — not part of the sheet's Title/Notes Save flow,
/// same as [_AssignToSection] calling [assignTaskProvider] directly.
///
/// Its own [ConsumerStatefulWidget] with its own [_currentStatus] state,
/// for the exact same reason [_AssignToSection] is its own widget — a tap
/// here should only rebuild this small row, not the whole sheet.
/// [_currentStatus] is seeded from [initialStatus] and updated
/// optimistically on tap, ahead of the write resolving, mirroring
/// [_AssignToSectionState]'s `_currentAssigneeUid`/
/// `_lastConfirmedAssigneeUid` rollback-on-error pattern exactly.
class _StatusSection extends ConsumerStatefulWidget {
  const _StatusSection({
    required this.spaceId,
    required this.taskId,
    required this.initialStatus,
  });

  final String spaceId;
  final String taskId;
  final TaskStatus initialStatus;

  @override
  ConsumerState<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends ConsumerState<_StatusSection> {
  late TaskStatus _currentStatus = widget.initialStatus;

  /// The last status actually confirmed written (or the sheet's opening
  /// value, before any tap) — see [_AssignToSectionState]'s
  /// `_lastConfirmedAssigneeUid` doc comment for the exact same reasoning.
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
        .updateStatus(spaceId: widget.spaceId, taskId: widget.taskId, status: status);
  }

  @override
  Widget build(BuildContext context) {
    // `ref.watch` (not just the `ref.read` in `_onStatusSelected`) — same
    // "Bad state: Future already completed" race [_AssignToSectionState]
    // hit and fixed by watching before any tap can reach the notifier.
    final updateState = ref.watch(updateStatusProvider);

    // Same `!isLoading` reasoning as [_AssignToSectionState]'s own
    // ref.listen — a state carries the previous value forward through
    // `AsyncLoading`, so it has to be excluded before treating a
    // transition as genuinely finished.
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
        SegmentedButton<TaskStatus>(
          segments: const [
            ButtonSegment(value: TaskStatus.todo, label: Text('Todo')),
            ButtonSegment(
              value: TaskStatus.inProgress,
              label: Text('In Progress'),
            ),
            ButtonSegment(value: TaskStatus.done, label: Text('Done')),
          ],
          selected: {_currentStatus},
          onSelectionChanged: (selection) =>
              _onStatusSelected(selection.first),
        ),
        if (updateState.hasError) ...[
          const SizedBox(height: 8),
          Text(
            'Could not update status. Try again.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// One tappable avatar in [_AssignToSection] — the current user's own
/// ("Me") renders larger than everyone else's, and the selected assignee
/// gets a colored ring, matching [SpaceSettingsScreen]'s `_MemberAvatarCircle`
/// visual logic for the photo-vs-initial fallback (kept as its own widget
/// here rather than imported — that one is private to its own file).
class _AssigneeAvatar extends StatelessWidget {
  const _AssigneeAvatar({
    required this.member,
    required this.isMe,
    required this.isSelected,
    required this.onTap,
  });

  final MemberAvatar member;
  final bool isMe;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = member.photoUrl != null && member.photoUrl!.isNotEmpty;
    final radius = isMe ? 28.0 : 22.0;
    final label = isMe ? 'Me' : member.displayName;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius + 4),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: CircleAvatar(
                radius: radius,
                backgroundImage: hasPhoto ? NetworkImage(member.photoUrl!) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              // maxLines: 1 — without it, a long display name wraps to a
              // second line instead of truncating, which is what actually
              // caused the reported overflow (not the avatar circle
              // itself): an unbounded Text inside this fixed-height
              // column pushes past the SizedBox's height budget.
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
