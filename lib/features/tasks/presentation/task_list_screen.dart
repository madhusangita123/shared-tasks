import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/task_detail_sheet.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/inline_add_task_row.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/task_row.dart';

/// S-03 — Task list. A custom header (not an [AppBar]) shows the space's
/// own name via [spaceProvider], falling back to "Tasks" while it loads,
/// over a subtitle of its member names. Lists every task in [spaceId] in
/// one flat list — issue #55 removed the old active/completed split and its
/// collapsible "Completed" [ExpansionTile] entirely; done tasks now stay
/// where they are, struck through in place. Tap a task to edit it, or use
/// its three-dot menu (Edit / Remove / Assign / Mark done). Adding is
/// inline via [InlineAddTaskRow] at the top and bottom of the list — issue
/// #55 also removed the FAB.
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
/// confirmed-deleted) and [_hasAutoOpenedTask] (issue #12).
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
    final task = tasks
        .where((task) => task.id == widget.openTaskId)
        .firstOrNull;
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
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      // Tapping anywhere that isn't itself interactive drops focus, which is
      // what lets an empty InlineAddTaskRow revert to its placeholder state —
      // without this nothing ever blurs it, so the row stays stuck as a text
      // field once tapped. Translucent so rows and buttons still get their
      // own taps.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(spaceId: widget.spaceId),
              Expanded(
                child: tasksState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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

                    final tasks = allTasks
                        .where(
                          (task) => !_pendingDeleteTaskIds.contains(task.id),
                        )
                        .toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children: [
                        InlineAddTaskRow(spaceId: widget.spaceId),
                        Container(height: 1, color: colors.border),
                        if (tasks.isEmpty)
                          const _EmptyHint()
                        else ...[
                          for (final (index, task) in tasks.indexed)
                            _AnimatedTaskRow(
                              key: ValueKey(task.id),
                              task: task,
                              spaceId: widget.spaceId,
                              isLast: index == tasks.length - 1,
                              onTap: () => _openTaskDetail(task),
                              onMenuSelected: (action) =>
                                  _onMenuSelected(action, task),
                            ),
                          InlineAddTaskRow(spaceId: widget.spaceId),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's custom header — a back link to Home, the space's own name,
/// its member names, and an overflow button into space settings. Replaces
/// the old [AppBar] (issue #55).
///
/// A back *icon* plus the word "Home", never a bare "←" text glyph: #57's
/// on-device testing found the glyph renders nearly invisibly at body size
/// on real Android devices.
class _Header extends ConsumerWidget {
  const _Header({required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    // Falls back to the generic "Tasks" title while the space doc is still
    // loading or fails to load — never blocks the task list itself on this
    // secondary lookup.
    final space = ref.watch(spaceProvider(spaceId)).valueOrNull;
    final spaceName = space?.name;
    // Same "secondary lookup, never block on it" treatment: while members
    // are loading (or the fetch failed) the subtitle is simply absent.
    final members = ref.watch(spaceMembersProvider(spaceId)).valueOrNull;
    final memberNames = (members ?? const [])
        .map((member) => member.displayName)
        .where((name) => name.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.home),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Home',
                    style: styles.bodyMedium.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  spaceName != null && spaceName.isNotEmpty
                      ? spaceName
                      : 'Tasks',
                  style: styles.headingMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              // Builder so `sharePositionOrigin` can be resolved from this
              // button's own render box — iPad's share sheet needs an anchor
              // rect or it silently never appears (see shareInviteLink).
              Builder(
                builder: (buttonContext) => IconButton(
                  icon: Icon(Icons.ios_share, color: colors.textSecondary),
                  tooltip: 'Share invite link',
                  onPressed: space == null
                      ? null
                      : () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          shareInviteLink(
                            Invite(
                              spaceId: space.id,
                              token: space.inviteToken,
                              expiresAt: space.inviteExpiresAt,
                            ),
                            sharePositionOrigin: box == null
                                ? null
                                : box.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: colors.textSecondary),
                tooltip: 'Space settings',
                // push, not go — matches every other in-app navigation in
                // this codebase (see HomeScreen's settings icon/FAB).
                onPressed: () =>
                    context.push(AppRoutes.spaceSettingsPath(spaceId)),
              ),
            ],
          ),
          if (memberNames.isNotEmpty)
            Text(
              memberNames,
              style: styles.bodySmall.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// Shown under the top [InlineAddTaskRow] when the space has no tasks yet.
/// Deliberately just a line of text — the add row directly above it is
/// already the call to action, and a second (bottom) add row on an empty
/// list would read as two identical controls.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Text(
        'No tasks yet',
        style: styles.bodySmall.copyWith(color: colors.textMuted),
      ),
    );
  }
}

/// Wraps [TaskRow] in a one-shot fade + rise-in entrance transition —
/// issue #11 (US-08), a small polish pass on top of the already-live
/// [taskListProvider] stream so a newly-synced task doesn't just pop into
/// the list instantly.
///
/// A [StatefulWidget] (not a plain animated wrapper built from [TaskRow]'s
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
    required this.isLast,
  });

  final Task task;
  final String spaceId;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;
  final bool isLast;

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
        child: TaskRow(
          task: widget.task,
          spaceId: widget.spaceId,
          onTap: widget.onTap,
          onMenuSelected: widget.onMenuSelected,
          isLast: widget.isLast,
        ),
      ),
    );
  }
}
