import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// Assign and Mark done aren't built yet (issues #9 and #10) — they appear
/// in the menu now as stubs (a "coming soon" message) rather than being
/// hidden, per explicit request, so the menu's final shape is visible early
/// and the two real actions slot into the same entries once built.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for [_pendingDeleteTaskIds] (tasks removed but not yet
/// confirmed-deleted) and doesn't need anything else beyond what
/// [ExpansionTile] already manages internally for the Completed section.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({required this.spaceId, super.key});

  final String spaceId;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  /// Ids of tasks removed via the menu and within their 5-second undo
  /// window — hidden immediately rather than waiting for the real delete to
  /// land.
  final Set<String> _pendingDeleteTaskIds = {};

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

  void _onStubActionPressed(String actionLabel) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$actionLabel — coming soon')));
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
        _onStubActionPressed('Assign');
      case 'mark_done':
        _onStubActionPressed('Mark done');
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
                _TaskRow(
                  task: task,
                  onTap: () => _openTaskDetail(task),
                  onMenuSelected: (action) => _onMenuSelected(action, task),
                ),
              if (completed.isNotEmpty)
                ExpansionTile(
                  title: Text('Completed (${completed.length})'),
                  initiallyExpanded: false,
                  children: [
                    for (final task in completed)
                      _TaskRow(
                        task: task,
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

/// One tappable task row with a three-dot menu (Edit / Remove / Assign /
/// Mark done — the latter two are stubs until issues #9/#10 land).
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onTap,
    required this.onMenuSelected,
  });

  final Task task;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == TaskStatus.done;
    final hasNotes = task.notes != null && task.notes!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          ),
          title: Text(
            task.title,
            style: isDone
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: hasNotes ? Text(task.notes!) : null,
          trailing: PopupMenuButton<String>(
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
        ),
      ),
    );
  }
}
