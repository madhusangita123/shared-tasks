import 'package:flutter/material.dart';

/// S-07 — Accept invite. Reached via `sharedtasks://join/{token}` deep link
/// (routed through [AppRoutes.joinSpacePath] — see
/// `core/router/deep_link_provider.dart`), with no explicit prior UI step.
///
/// TODO(#30): call the real joinSpaceByToken Cloud Function via the invite
/// feature's repository, then navigate to Home (or show an error) once #30
/// lands. For now this just shows a loading state to prove the deep-link
/// route wiring works end-to-end (issue #29).
class JoinSpaceScreen extends StatelessWidget {
  const JoinSpaceScreen({required this.token, super.key});

  /// The invite token extracted from the deep link's path. Unused until
  /// #30 wires up the real join call, but kept here so that call has
  /// something to pass.
  final String token;

  @override
  Widget build(BuildContext context) {
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
