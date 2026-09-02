import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/core/widgets/app_text_field.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/presentation/providers/tasks_provider.dart';

/// S-04 — Task detail sheet. Shown via `showModalBottomSheet` for both
/// adding a new task (`task == null`) and editing an existing one
/// (`task` supplied).
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for the [TextEditingController]s and inline validation error text,
/// the same reasoning [CreateSpaceScreen] needed `StatefulWidget` for.
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
      if (next.hasValue && !next.hasError) {
        Navigator.of(context).pop();
      }
    });

    final submitState = ref.watch(controllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                autofocus: true,
                maxLength: AppConstants.taskTitleMaxLength,
                errorText: _validationError,
              ),
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
    );
  }
}
