import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/invite/presentation/providers/invite_provider.dart';

/// S-07 — Accept invite. Reached via `sharedtasks://join/{token}` deep link
/// (routed through [AppRoutes.joinSpacePath] — see
/// `core/router/deep_link_provider.dart`), with no explicit prior UI step.
///
/// Calls the `joinSpaceByToken` Cloud Function with [token] as soon as this
/// screen mounts. On success — including the already-a-member no-op the
/// function itself treats as success — navigates straight to Home, no
/// accept screen. On failure (invalid/expired token, not signed in, or a
/// network error) shows an inline message with a way back to Home, never a
/// crash or a silent failure (see issue #30).
class JoinSpaceScreen extends ConsumerStatefulWidget {
  const JoinSpaceScreen({required this.token, super.key});

  /// The invite token extracted from the deep link's path.
  final String token;

  @override
  ConsumerState<JoinSpaceScreen> createState() => _JoinSpaceScreenState();
}

class _JoinSpaceScreenState extends ConsumerState<JoinSpaceScreen> {
  @override
  void initState() {
    super.initState();
    // `join()` sets `state = const AsyncLoading()` synchronously as its
    // first statement (before its first `await`), so calling it directly
    // here would mutate a provider mid-`initState` — Riverpod disallows
    // that (`_debugCanModifyProviders`) because the widget tree is still
    // being built. `Future.microtask` defers the call to right after this
    // build finishes, which is exactly the fix Riverpod's own assertion
    // message recommends.
    Future.microtask(
      () => ref.read(joinSpaceProvider.notifier).join(widget.token),
    );
  }

  /// Same no-modal inline-error convention as [CreateSpaceScreen]'s
  /// `_errorMessage` — duplicated here since it's not shared.
  String _errorMessage(Object? error) {
    if (error is AppFailure) return error.message;
    return 'Could not join this space. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(joinSpaceProvider, (previous, next) {
      final spaceId = next.valueOrNull;
      if (spaceId != null) {
        context.go(AppRoutes.home);
      }
    });

    final state = ref.watch(joinSpaceProvider);

    if (state.hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorMessage(state.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Joining...'),
          ],
        ),
      ),
    );
  }
}
