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
/// function itself treats as success — navigates straight into the joined
/// space's task list, no accept screen and no detour through Home first
/// (raised during #37's manual testing — landing on Home after tapping an
/// invite link for a *specific* space made no sense once there was more
/// than one space to land among). On failure (invalid/expired token, not
/// signed in, or a network error) shows an inline message with a way back
/// to Home — Home is still the right fallback there, since a failed join
/// has no space to land in (see issue #30).
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
        // `go` alone would replace the whole navigation stack with just the
        // task list screen — fine on a warm start where Home was already
        // on the stack, but on a cold start (the deep link is the very
        // first screen) it left the task list with no way back to Home at
        // all (no back arrow, nothing to pop to — found via real-device
        // testing). `go` to Home first, establishing it as the stack's
        // root, then `push` the task list on top — this matches exactly
        // how HomeScreen's own space cards navigate (see
        // home_screen.dart's `context.push(AppRoutes.taskListPath(...))`),
        // giving a normal working back arrow regardless of cold vs warm
        // start.
        context.go(AppRoutes.home);
        context.push(AppRoutes.taskListPath(spaceId));
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
