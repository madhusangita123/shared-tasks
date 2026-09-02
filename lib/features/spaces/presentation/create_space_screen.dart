import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/core/widgets/app_text_field.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';

/// S-05 — Create space. A simple name input; on submit, creates a private
/// space owned by the signed-in user and navigates to its (empty) task
/// list.
///
/// A [ConsumerStatefulWidget] rather than a [ConsumerWidget] — needs local
/// state for the [TextEditingController] and inline validation error text,
/// the same reasoning [SettingsScreen]'s `_ProfileAvatar` needed
/// `StatefulWidget` for image-failure tracking.
class CreateSpaceScreen extends ConsumerStatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  ConsumerState<CreateSpaceScreen> createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends ConsumerState<CreateSpaceScreen> {
  final _nameController = TextEditingController();

  /// Inline validation error text. Stays `null` until the user has
  /// interacted / attempted submit — a pristine empty field shows no error.
  String? _validationError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates the current field value. Returns `true` if valid; otherwise
  /// sets [_validationError] and returns `false`.
  bool _validate() {
    final trimmed = _nameController.text.trim();
    if (trimmed.length < AppConstants.spaceNameMinLength ||
        trimmed.length > AppConstants.spaceNameMaxLength) {
      setState(
        () => _validationError =
            'Space name must be ${AppConstants.spaceNameMinLength}–'
            '${AppConstants.spaceNameMaxLength} characters',
      );
      return false;
    }
    setState(() => _validationError = null);
    return true;
  }

  void _onCreatePressed() {
    if (!_validate()) return;
    ref
        .read(createSpaceProvider.notifier)
        .createSpace(_nameController.text.trim());
  }

  /// Same no-modal inline-error convention as [SettingsScreen]'s
  /// `_errorMessage` — duplicated here since it's not shared.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Could not create space. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Space?>>(createSpaceProvider, (previous, next) {
      final space = next.valueOrNull;
      if (space != null) {
        context.pushReplacement(AppRoutes.taskListPath(space.id));
      }
    });

    final createState = ref.watch(createSpaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create space')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Space name',
                controller: _nameController,
                autofocus: true,
                maxLength: AppConstants.spaceNameMaxLength,
                errorText: _validationError,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Create',
                isLoading: createState.isLoading,
                onPressed: _onCreatePressed,
              ),
              if (createState.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage(createState.error),
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
