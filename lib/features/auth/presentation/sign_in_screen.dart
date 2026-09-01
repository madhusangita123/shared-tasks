import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';

/// S-01 — Sign in screen. App logo, tagline, and a single
/// "Continue with Google" button. Google sign-in only — no email/password,
/// no guest mode (ADR-006).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInState = ref.watch(signInProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.checklist_rounded, size: 64),
                const SizedBox(height: 24),
                Text(
                  'SharedTasks',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Share tasks with your household',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: 'Continue with Google',
                  icon: Icons.login,
                  isLoading: signInState.isLoading,
                  onPressed: () =>
                      ref.read(signInProvider.notifier).signInWithGoogle(),
                ),
                if (signInState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage(signInState.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(signInProvider.notifier).signInWithGoogle(),
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maps the failure to the exact inline copy required by the acceptance
  /// criteria — [NetworkFailure]'s message doesn't include "Try again." so
  /// it's appended here; [AuthFailure] already carries the full sentence.
  String _errorMessage(Object? error) {
    if (error is NetworkFailure) return '${error.message}. Try again.';
    if (error is AppFailure) return error.message;
    return 'Sign in failed. Try again.';
  }
}
