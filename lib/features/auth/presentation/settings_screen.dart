import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/widgets/app_button.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';

/// Settings screen (issue #21) — not the PRD's S-06 (that's Space Settings).
/// Shows the signed-in user's profile (photo, name,
/// email) and a Sign out button.
///
/// Only ever reached while authenticated (the router's redirect guard keeps
/// unauthenticated users on the sign-in screen), so [authStateProvider]
/// should be non-null here in practice. A transient null while the stream
/// re-emits is handled with a loading indicator rather than a crash.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final signOutState = ref.watch(signOutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProfileAvatar(user: user),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      AppButton(
                        label: 'Sign out',
                        icon: Icons.logout,
                        isLoading: signOutState.isLoading,
                        onPressed: () =>
                            ref.read(signOutProvider.notifier).signOut(),
                      ),
                      if (signOutState.hasError) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage(signOutState.error),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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

  /// Same no-modal inline-error convention as [SignInScreen]'s
  /// `_errorMessage` — the AC doesn't specify exact copy here, so a simple
  /// generic message is used.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Sign out failed. Try again.';
  }
}

/// The profile photo, or a fallback initial-letter avatar.
///
/// Flutter's image pipeline never throws an uncaught exception on a broken
/// `NetworkImage` — it reports the error internally and would otherwise
/// just render an empty circle. [onBackgroundImageError] catches that and
/// falls back to the initials avatar instead of leaving a blank circle.
class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({required this.user});

  final AppUser user;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _imageFailed = false;

  @override
  Widget build(BuildContext context) {
    final showImage = widget.user.photoUrl != null && !_imageFailed;

    return CircleAvatar(
      radius: 40,
      backgroundImage: showImage ? NetworkImage(widget.user.photoUrl!) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _imageFailed = true);
            }
          : null,
      child: showImage
          ? null
          : Text(
              widget.user.displayName.isNotEmpty
                  ? widget.user.displayName[0].toUpperCase()
                  : '?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
    );
  }
}
