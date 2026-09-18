import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/app_logo.dart';
import 'package:shared_tasks/features/auth/presentation/widgets/google_sign_in_button.dart';

/// S-01 — Sign in screen. App logo, tagline, and a single
/// "Continue with Google" button. Google sign-in only — no email/password,
/// no guest mode (ADR-006).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signInState = ref.watch(signInProvider);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(),
                const SizedBox(height: 20),
                Text(
                  'SharedTasks',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tasks, together.',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                GoogleSignInButton(
                  isLoading: signInState.isLoading,
                  onPressed: () =>
                      ref.read(signInProvider.notifier).signInWithGoogle(),
                ),
                if (signInState.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(signInState.error),
                    style: TextStyle(fontSize: 13, color: colors.danger),
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

  /// Maps the failure to the exact inline copy required by the acceptance
  /// criteria — [NetworkFailure]'s message doesn't include "Try again." so
  /// it's appended here; [AppFailure] already carries the full sentence.
  String _errorMessage(Object? error) {
    if (error is NetworkFailure) return '${error.message}. Try again.';
    if (error is AppFailure) return error.message;
    return 'Sign in failed. Try again.';
  }
}
