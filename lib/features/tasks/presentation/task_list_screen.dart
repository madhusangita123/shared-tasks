import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';

/// S-03 — Task list. AppBar title shows the space's own name (via
/// [spaceProvider], falling back to "Tasks" while it loads). Lists every
/// task in [spaceId], active tasks at top and completed tasks collapsed
/// below. Tap a task to edit it, or use its three-dot menu (Edit / Remove /
/// Assign / Mark done). FAB adds a new one.
///
/// No swipe-to-delete — deliberately replaced by the per-row menu's Remove
/// action at the user's request (issue #8 originally specified a
/// `Dismissible` swipe gesture; this is a documented deviation). Remove
/// keeps the same confirm-if-in-progress + 5-second-undo behavior the swipe
/// gesture would have had — only the trigger changed, not the safety net.
///
/// Assign is real as of issue #9 — opens the same sheet Edit does, where
/// the actual "Assign to" avatar row lives (too wide for a popup menu
/// entry). Mark done is real as of issue #10 — a shortcut straight to
/// [TaskStatus.done] regardless of the task's current status, distinct
/// from the row's own leading status icon, which instead cycles
/// todo → in_progress → done → todo one step at a time on tap.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for [_pendingDeleteTaskIds] (tasks removed but not yet
/// confirmed-deleted), [_hasAutoOpenedTask] (issue #12), and doesn't need
/// anything else beyond what [ExpansionTile] already manages internally for
/// the Completed section.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({required this.spaceId, super.key, this.openTaskId});

  final String spaceId;

  /// Set only when this screen was reached by tapping a push notification
  /// (issue #12 — see `AppRoutes.taskListPath` and
  /// `notificationTapProvider`). Once [taskListProvider]'s data includes a
  /// task with this id, its detail sheet is opened automatically, exactly
  /// once. `null` on every other navigation into this screen, which leaves
  /// behavior completely unchanged from before this issue.
  final String? openTaskId;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  /// Ids of tasks removed via the menu and within their 5-second undo
  /// window — hidden immediately rather than waiting for the real delete to
  /// land.
  final Set<String> _pendingDeleteTaskIds = {};

  /// Guards [widget.openTaskId]'s auto-open (issue #12) so it fires at most
  /// once per screen instance — without this, every subsequent
  /// [taskListProvider] emission (a live Firestore listener, so this can
  /// fire often) would reopen the sheet even after the user closed it.
  bool _hasAutoOpenedTask = false;

  @override
  void didUpdateWidget(TaskListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A second notification tap while this exact screen instance is still
    // around (e.g. `push`ing the same spaceId's task list again lands on
    // an existing route rather than a fresh one, depending on how the
    // router diffs it) would otherwise leave `_hasAutoOpenedTask` stuck
    // `true` from the *previous* tap's task, silently no-op'ing this one —
    // the exact "sometimes it just doesn't open" flakiness this guards
    // against. Reset whenever it names a genuinely new task to open.
    if (widget.openTaskId != oldWidget.openTaskId) {
      _hasAutoOpenedTask = false;
    }
  }

  /// Opens [widget.openTaskId]'s detail sheet the first time it's found in
  /// [tasks], then never again for this screen instance. A no-op once
  /// [_hasAutoOpenedTask] is already true, [widget.openTaskId] is `null`,
  /// or the task isn't in the list yet (e.g. the very first, still-loading
  /// emission) — called from [build] on every data emission, so it's safe
  /// to call unconditionally there.
  void _maybeAutoOpenTask(List<Task> tasks) {
    if (_hasAutoOpenedTask || widget.openTaskId == null) return;
    final task = tasks.where((task) => task.id == widget.openTaskId).firstOrNull;
    if (task == null) return;

    _hasAutoOpenedTask = true;
    // Deferred a frame — calling this synchronously from within build()
    // would try to push a route (showModalBottomSheet) while the widget
    // tree is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openTaskDetail(task);
    });
  }

  Future<bool> _confirmDelete(Task task) async {
    if (task.status != TaskStatus.inProgress) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete in-progress task?'),
        content: const Text(
          'This task is still in progress. Are you sure you want to delete it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _onRemovePressed(Task task) async {
    final confirmed = await _confirmDelete(task);
    if (!confirmed || !mounted) return;

    // Captured now, while definitely still mounted, so the real delete
    // below can still fire even if the user navigates away from this
    // screen before the undo window closes. `ref` itself becomes unsafe
    // to use once the widget is disposed, but a notifier object read off
    // it is still a plain Dart object — calling a method on it later
    // doesn't require the widget that read it to still be mounted. Without
    // this, the delete the "deleted" snackbar promised would be silently
    // dropped rather than just delayed.
    final deleteNotifier = ref.read(deleteTaskProvider.notifier);

    setState(() => _pendingDeleteTaskIds.add(task.id));

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text('"${task.title}" deleted'),
            duration: const Duration(seconds: 5),
            // SnackBar defaults `persist` to true whenever an `action` is
            // set, which disables the duration-based auto-dismiss timer
            // entirely (its internal Timer still fires, but short-circuits
            // on `if (snackBar.persist) return;`). Without this, `.closed`
            // never resolves with SnackBarClosedReason.timeout, so the real
            // delete below would only ever happen via an explicit Undo tap
            // — never automatically after 5 seconds as intended.
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () =>
                  setState(() => _pendingDeleteTaskIds.remove(task.id)),
            ),
          ),
        )
        .closed
        .then((reason) {
          // _pendingDeleteTaskIds is a plain field on this State object —
          // reading it doesn't require the widget to still be mounted, only
          // mutating it (via setState) does. The delete call itself must
          // run regardless of mounted, or a user who navigated away during
          // the undo window would keep a task they believed was deleted.
          if (reason != SnackBarClosedReason.action &&
              _pendingDeleteTaskIds.contains(task.id)) {
            deleteNotifier.deleteTask(spaceId: widget.spaceId, taskId: task.id);
          }
        });
  }

  void _openTaskDetail(Task? task) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskDetailSheet(spaceId: widget.spaceId, task: task),
    );
  }

  void _onMenuSelected(String action, Task task) {
    switch (action) {
      case 'edit':
        _openTaskDetail(task);
      case 'remove':
        _onRemovePressed(task);
      case 'assign':
        // Issue #9 — the real "Assign to" UI lives in TaskDetailSheet
        // (needs the full member-avatar row, not something that fits a
        // popup menu entry), so this now opens the same sheet Edit does
        // rather than being a separate quick-assign popup.
        _openTaskDetail(task);
      case 'mark_done':
        ref
            .read(updateStatusProvider.notifier)
            .updateStatus(
              spaceId: widget.spaceId,
              taskId: task.id,
              status: TaskStatus.done,
            );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(taskListProvider(widget.spaceId));
    // Falls back to the generic "Tasks" title while the space doc is
    // still loading or fails to load — never blocks the task list itself
    // on this secondary lookup.
    final spaceName = ref.watch(spaceProvider(widget.spaceId)).valueOrNull?.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(spaceName != null && spaceName.isNotEmpty ? spaceName : 'Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            // push, not go — matches every other in-app navigation in this
            // codebase (see HomeScreen's settings icon/FAB).
            onPressed: () =>
                context.push(AppRoutes.spaceSettingsPath(widget.spaceId)),
          ),
        ],
      ),
      body: tasksState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Something went wrong loading tasks.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (allTasks) {
          _maybeAutoOpenTask(allTasks);

          if (allTasks.isEmpty) return const _EmptyState();

          final tasks = allTasks
              .where((task) => !_pendingDeleteTaskIds.contains(task.id))
              .toList();
          final active = tasks
              .where((task) => task.status != TaskStatus.done)
              .toList();
          final completed = tasks
              .where((task) => task.status == TaskStatus.done)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final task in active)
                _AnimatedTaskRow(
                  key: ValueKey(task.id),
                  task: task,
                  spaceId: widget.spaceId,
                  onTap: () => _openTaskDetail(task),
                  onMenuSelected: (action) => _onMenuSelected(action, task),
                ),
              if (completed.isNotEmpty)
                ExpansionTile(
                  title: Text('Completed (${completed.length})'),
                  initiallyExpanded: true,
                  children: [
                    for (final task in completed)
                      _AnimatedTaskRow(
                        key: ValueKey(task.id),
                        task: task,
                        spaceId: widget.spaceId,
                        onTap: () => _openTaskDetail(task),
                        onMenuSelected: (action) =>
                            _onMenuSelected(action, task),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskDetail(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Friendly prompt shown when the space has no tasks yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [_TaskRow] in a one-shot fade + rise-in entrance transition —
/// issue #11 (US-08), a small polish pass on top of the already-live
/// [taskListProvider] stream so a newly-synced task doesn't just pop into
/// the list instantly.
///
/// A [StatefulWidget] (not a plain animated wrapper built from [_TaskRow]'s
/// caller) purely so it owns its own one-shot [AnimationController] that
/// runs exactly once, in [initState] — not on every rebuild, which would
/// replay the animation on every data change of an already-visible row
/// (an edit, a status change, a new assignee). Callers key each instance by
/// `task.id` (see the `ListView`'s `itemBuilder`s in [TaskListScreen]), so
/// an existing row keeps its existing [State] — and therefore never repeats
/// the animation — while only a genuinely new task id mounts a fresh one.
class _AnimatedTaskRow extends StatefulWidget {
  const _AnimatedTaskRow({
    required super.key,
    required this.task,
    required this.spaceId,
    required this.onTap,
    required this.onMenuSelected,
  });

  final Task task;
  final String spaceId;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  State<_AnimatedTaskRow> createState() => _AnimatedTaskRowState();
}

class _AnimatedTaskRowState extends State<_AnimatedTaskRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: _TaskRow(
          task: widget.task,
          spaceId: widget.spaceId,
          onTap: widget.onTap,
          onMenuSelected: widget.onMenuSelected,
        ),
      ),
    );
  }
}

/// One tappable task row with a three-dot menu (Edit / Remove / Assign /
/// Mark done, all real as of issues #9 and #10). The leading status icon
/// (issue #10) is its own independently-tappable target — separate from
/// the row's own `onTap`, which opens the detail sheet — cycling
/// todo → in_progress → done → todo one step per tap.
///
/// A [ConsumerWidget] (not [StatelessWidget], as before #9) — needs
/// [spaceMembersProvider] to resolve [Task.assigneeUid] into a displayable
/// avatar.
class _TaskRow extends ConsumerWidget {
  const _TaskRow({
    required this.task,
    required this.spaceId,
    required this.onTap,
    required this.onMenuSelected,
  });

  final Task task;
  final String spaceId;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.status == TaskStatus.done;
    final hasNotes = task.notes != null && task.notes!.isNotEmpty;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: _StatusIcon(
            status: task.status,
            onTap: () => ref
                .read(updateStatusProvider.notifier)
                .updateStatus(
                  spaceId: spaceId,
                  taskId: task.id,
                  status: task.status.next,
                ),
          ),
          title: Text(
            task.title,
            style: isDone
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: hasNotes ? Text(task.notes!) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AssigneeIndicator(assignee: assignee),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: onMenuSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Remove'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'assign',
                    child: ListTile(
                      leading: Icon(Icons.person_add_outlined),
                      title: Text('Assign'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'mark_done',
                    child: ListTile(
                      leading: Icon(Icons.done_outlined),
                      title: Text('Mark done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The leading status icon on a task card — issue #10. Its own tappable
/// target (an [InkWell] sized/shaped to match [ListTile]'s usual leading
/// icon slot), deliberately separate from the row's own `onTap` (which
/// opens the detail sheet) so tapping it doesn't also open the sheet.
/// Tapping cycles [TaskStatus.next] — todo → in_progress → done → todo.
///
/// Icon and color both vary by status — not just done-vs-not — following
/// the same "distinct, never invent a new palette" convention
/// [_AssigneeIndicator] uses: neutral outline for todo (matching that
/// widget's unassigned styling), the theme's own tertiary tone for
/// in_progress (a distinct, non-alarming "in flight" signal — deliberately
/// not an error/warning color), and `colorScheme.primary` for done
/// (matching [_AssignToSection]'s own selection-ring convention for "the
/// completed/selected state").
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.onTap});

  final TaskStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      TaskStatus.todo => (
        Icons.radio_button_unchecked,
        colorScheme.outline,
      ),
      TaskStatus.inProgress => (Icons.timelapse, colorScheme.tertiary),
      TaskStatus.done => (Icons.check_circle, colorScheme.primary),
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
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

/// The assignee indicator on a task card — issue #9. Shows the assigned
/// member's avatar (photo, or their initial as a fallback), or a neutral
/// "unassigned" icon when nobody's assigned. Deliberately neutral either
/// way — the AC is explicit that "unassigned" is not a warning state, so
/// this uses the same outline styling regardless, never an error/warning
/// color.
class _AssigneeIndicator extends StatelessWidget {
  const _AssigneeIndicator({required this.assignee});

  final MemberAvatar? assignee;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;

    if (assignee == null) {
      return Tooltip(
        message: 'Unassigned',
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.transparent,
          child: Icon(Icons.person_outline, size: 20, color: outline),
        ),
      );
    }

    final hasPhoto = assignee!.photoUrl != null && assignee!.photoUrl!.isNotEmpty;
    return Tooltip(
      message: assignee!.displayName,
      child: CircleAvatar(
        radius: 14,
        backgroundImage: hasPhoto ? NetworkImage(assignee!.photoUrl!) : null,
        child: hasPhoto
            ? null
            : Text(
                assignee!.displayName.isNotEmpty
                    ? assignee!.displayName[0].toUpperCase()
                    : '?',
                style: Theme.of(context).textTheme.labelSmall,
              ),
      ),
    );
  }
}
