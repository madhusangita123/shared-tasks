import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/core/theme/app_text_styles.dart';
import 'package:shared_tasks/features/notifications/notification_permission.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:shared_tasks/features/spaces/presentation/providers/spaces_provider.dart';
import 'package:shared_tasks/features/spaces/presentation/widgets/quick_pick_chips.dart';

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
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isValid {
    final len = _nameController.text.trim().length;
    return len >= AppConstants.spaceNameMinLength &&
        len <= AppConstants.spaceNameMaxLength;
  }

  bool get _showError => _nameController.text.isNotEmpty && !_isValid;

  void _onChipSelected(String value) {
    _nameController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _focusNode.requestFocus();
  }

  void _onCreatePressed() {
    if (!_isValid) return;
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
        // Issue #12 — "Notification permission requested after user's
        // first space is created or joined." Fire-and-forget: this screen
        // is navigating away immediately after, and
        // requestNotificationPermission already never throws.
        requestNotificationPermission();
        context.pushReplacement(AppRoutes.taskListPath(space.id));
      }
    });

    final createState = ref.watch(createSpaceProvider);

    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    final canCreate = _isValid && !createState.isLoading;
    OutlineInputBorder inputBorder(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: 1.5),
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.home),
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
                              'Cancel',
                              style: styles.bodyMedium.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'New space',
                      style: styles.headingMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Give it a name',
                      style: styles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      focusNode: _focusNode,
                      autofocus: true,
                      maxLength: AppConstants.spaceNameMaxLength,
                      style: TextStyle(fontSize: 15, color: colors.textPrimary),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: colors.surfaceElevated,
                        hintText: 'e.g. House chores',
                        hintStyle: TextStyle(color: colors.textMuted),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        enabledBorder: inputBorder(colors.border),
                        focusedBorder: inputBorder(colors.primary),
                      ),
                    ),
                    if (_showError) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Space name must be ${AppConstants.spaceNameMinLength}–'
                        '${AppConstants.spaceNameMaxLength} characters',
                        style: TextStyle(fontSize: 12, color: colors.danger),
                      ),
                    ],
                    const SizedBox(height: 20),
                    QuickPickChips(onSelected: _onChipSelected),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (createState.hasError) ...[
                    Text(
                      _errorMessage(createState.error),
                      style: TextStyle(fontSize: 13, color: colors.danger),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Semantics(
                    button: true,
                    enabled: canCreate,
                    child: Material(
                      color: canCreate ? colors.primary : colors.textMuted,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: canCreate ? _onCreatePressed : null,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Center(
                            child: createState.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create space',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
