import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/assignee_picker.dart';
import 'package:shared_tasks/features/tasks/presentation/widgets/status_pills.dart';

/// S-04 — the task detail sheet, shown via `showModalBottomSheet` when a
/// task is tapped on [TaskListScreen]. Issue #56's redesign.
///
/// Edit-only: issue #55 replaced the old "add task" flow (FAB → this sheet
/// with a null task) with [InlineAddTaskRow], so [task] is now required and
/// non-null and every add-mode branch is gone.
///
/// There is no Save button. Everything commits as it's changed — the title
/// on submit, the notes on submit or blur, the status on a pill tap
/// ([StatusPills]) and the assignee on an avatar tap ([AssigneePicker]) —
/// and the user dismisses the sheet themselves by tapping outside, dragging
/// down or pressing back. Delete is delegated back to the list screen via
/// [onDelete], which owns the confirm-if-in-progress dialog and the
/// 5-second undo SnackBar.
///
/// [StatusPills] and [AssigneePicker] are separate widgets with their own
/// state specifically so tapping a pill or an avatar only rebuilds that
/// small subtree — folding their state into this one would `setState` the
/// whole sheet on every tap, visibly re-laying-out the title and notes
/// fields for no reason.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for the [TextEditingController]s, the title's text/edit-field
/// toggle and the inline validation error text.
class TaskDetailSheet extends ConsumerStatefulWidget {
  const TaskDetailSheet({
    required this.spaceId,
    required this.task,
    required this.onDelete,
    super.key,
  });

  final String spaceId;
  final Task task;

  /// Invoked after this sheet pops itself, so the list screen's existing
  /// delete flow (confirm-if-in-progress, undo SnackBar, delete-even-if-
  /// navigated-away) runs untouched rather than being reimplemented here.
  final VoidCallback onDelete;

  @override
  ConsumerState<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<TaskDetailSheet> {
  late final _titleController = TextEditingController(text: widget.task.title);
  late final _notesController = TextEditingController(text: widget.task.notes);
  final _notesFocusNode = FocusNode();

  /// `true` while the title has been tapped and swapped itself for a text
  /// field. Reverts to the plain text display on a valid submit.
  bool _isEditingTitle = false;

  /// Inline validation error text for the title. Stays `null` until the
  /// user has attempted a submit — a pristine field shows no error.
  String? _validationError;

  /// Held so a write survives the sheet being dismissed: the notes blur
  /// commit fires as the route pops, and the `.then` that follows it lands
  /// after this widget is gone. `ref` is unsafe by then, but a notifier read
  /// off it is a plain Dart object and stays callable — the same trick
  /// `TaskListScreen._onRemovePressed` uses for its delayed delete.
  ///
  /// Assigned in [initState], not lazily — a `late` initialiser would defer
  /// the `ref.read` until first use, which can be past that point.
  late final UpdateTaskController _updateNotifier;

  @override
  void initState() {
    super.initState();
    _updateNotifier = ref.read(updateTaskProvider.notifier);
    _notesFocusNode.addListener(_onNotesFocusChanged);
  }

  @override
  void dispose() {
    _notesFocusNode
      ..removeListener(_onNotesFocusChanged)
      ..dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// The title and notes as last sent to Firestore — seeded from the task
  /// the sheet opened with. See [_save].
  ///
  /// Normalised exactly the way [_save] normalises the controllers, or the
  /// comparison there comes out dirty for a task that nobody touched: a
  /// stored `notes` of `''` would differ from the `null` that an empty field
  /// maps to, and a stored title with stray whitespace would differ from its
  /// own trimmed self.
  late String _savedTitle = widget.task.title.trim();
  late String? _savedNotes = _normaliseNotes(widget.task.notes);

  static String? _normaliseNotes(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Set when any write fails. [_savedTitle]/[_savedNotes] may then describe
  /// values Firestore never received, so the dirty check can't be trusted
  /// and the next [_save] sends unconditionally.
  ///
  /// Deliberately coarse. An earlier version rolled `_saved*` back to the
  /// failed write's previous values, which is right for one write but not
  /// for several overlapping ones: if two writes both failed and the older
  /// one resolved first, `_saved*` ended on a value Firestore never had, and
  /// retyping that value was skipped as unchanged. Working out exactly which
  /// overlapping write failed is where that went wrong, and one spare write
  /// after an error costs nothing.
  bool _savedMayBeStale = false;

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

  /// The single write path for both fields — each always sends the other's
  /// current value too, since `updateTask` writes title and notes together.
  ///
  /// Skips the write entirely when neither field actually changed. Notes
  /// commit on blur, so without this, merely focusing the notes field and
  /// tapping away would write — bumping the task's `updatedAt`, which
  /// reorders the space on Home (it sorts by most recently updated). Just
  /// opening a task and looking at it would shuffle the list.
  void _save() {
    final title = _titleController.text.trim();
    final trimmedNotes = _notesController.text.trim();
    final notes = trimmedNotes.isEmpty ? null : trimmedNotes;
    final unchanged = title == _savedTitle && notes == _savedNotes;
    if (unchanged && !_savedMayBeStale) return;

    // Moved at attempt time so a second blur with nothing further typed
    // doesn't re-send the same text.
    _savedTitle = title;
    _savedNotes = notes;
    _savedMayBeStale = false;

    // Branch on what THIS call returned, never on updateTaskProvider's state:
    // the provider is shared, so with two writes in flight (submit the title,
    // then blur the notes before the first resolves) the state on resume can
    // describe the other write.
    unawaited(
      _updateNotifier
          .updateTask(
            spaceId: widget.spaceId,
            taskId: widget.task.id,
            title: title,
            notes: notes,
          )
          .then((failure) {
            if (failure != null) _savedMayBeStale = true;
          }),
    );
  }

  void _onTitleSubmitted(String _) {
    // Invalid → stay in edit mode with the error showing, rather than
    // reverting to a text display of something that was never saved.
    if (!_validate()) return;
    _save();
    setState(() => _isEditingTitle = false);
  }

  void _onNotesFocusChanged() {
    // Blur is a commit for notes — a multiline field has no "submit" key
    // the way the title does, so leaving it is what saves it.
    if (_notesFocusNode.hasFocus) return;
    if (_titleController.text.trim().isEmpty) return;
    _save();
  }

  /// Same no-modal inline-error convention as [CreateSpaceScreen]'s
  /// `_errorMessage` — duplicated here since it's not shared.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Could not save task. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final updateState = ref.watch(updateTaskProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.radiusLg),
          ),
          border: Border(top: BorderSide(color: colors.border)),
          boxShadow: [
            BoxShadow(
              // Derived from a theme token rather than a fixed rgba, so the
              // shadow stays correct in dark mode.
              color: colors.textPrimary.withValues(alpha: 0.08),
              offset: const Offset(0, -4),
              blurRadius: 20,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            // SingleChildScrollView — this sheet is tall enough that it can
            // overflow when the keyboard opens and shrinks the available
            // height; a plain fixed Column has nowhere for the extra content
            // to go. Scrolls instead of overflowing, with no visual change
            // when everything already fits.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: colors.borderStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _buildTitle(colors, styles),
                  if (_validationError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _validationError!,
                      style: styles.bodySmall.copyWith(color: colors.danger),
                    ),
                  ],
                  const SizedBox(height: 16),
                  StatusPills(
                    spaceId: widget.spaceId,
                    taskId: widget.task.id,
                    initialStatus: widget.task.status,
                  ),
                  const SizedBox(height: 16),
                  AssigneePicker(
                    spaceId: widget.spaceId,
                    taskId: widget.task.id,
                    initialAssigneeUid: widget.task.assigneeUid,
                  ),
                  const SizedBox(height: 16),
                  _buildNotes(colors, styles),
                  const SizedBox(height: 16),
                  _buildDeleteAction(colors),
                  if (updateState.hasError) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage(updateState.error),
                      textAlign: TextAlign.center,
                      style: styles.bodySmall.copyWith(color: colors.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(AppColors colors, AppTextStyles styles) {
    final titleStyle = styles.bodyLarge.copyWith(color: colors.textPrimary);

    if (!_isEditingTitle) {
      return InkWell(
        onTap: () => setState(() => _isEditingTitle = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          // The controller's text, not `widget.task.title` — this sheet
          // holds a one-shot snapshot of the task taken when it opened and
          // never rebuilds from the list's stream, so reading the entity
          // back here would show the pre-edit title after a save.
          child: Text(_titleController.text, style: titleStyle),
        ),
      );
    }

    return TextField(
      controller: _titleController,
      autofocus: true,
      textInputAction: TextInputAction.done,
      maxLength: AppConstants.taskTitleMaxLength,
      style: titleStyle,
      decoration: const InputDecoration(
        isDense: true,
        // AppTheme's global inputDecorationTheme fills every field with
        // `surface`; opted out here so the field reads as the title line
        // having become typable rather than as a grey form box appearing.
        filled: false,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onSubmitted: _onTitleSubmitted,
    );
  }

  /// Notes are deliberately kept, even though issue #56's spec omits them:
  /// issue #55 removed the notes subtitle from the task row precisely
  /// *because* notes live in this sheet, and dropping the field here would
  /// strand every note already written.
  Widget _buildNotes(AppColors colors, AppTextStyles styles) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      borderSide: BorderSide(color: colors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOTES', style: styles.label.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          focusNode: _notesFocusNode,
          maxLines: 3,
          maxLength: AppConstants.taskNotesMaxLength,
          style: styles.bodyMedium.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            // Same opt-out as the title field — see `_buildTitle`.
            filled: false,
            counterText: '',
            hintText: 'Add notes...',
            hintStyle: styles.bodyMedium.copyWith(color: colors.textMuted),
            contentPadding: const EdgeInsets.all(10),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }

  Widget _buildDeleteAction(AppColors colors) {
    return InkWell(
      // Pops first, then delegates: the confirm dialog, the undo SnackBar
      // and the actual delete all belong to TaskListScreen, which is still
      // mounted underneath this sheet.
      onTap: () {
        Navigator.of(context).pop();
        widget.onDelete();
      },
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: Container(
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.dangerBg,
          borderRadius: BorderRadius.circular(AppRadius.radiusSm),
          border: Border.all(color: colors.dangerBorder),
        ),
        child: Text(
          'Delete task',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.danger,
          ),
        ),
      ),
    );
  }
}
