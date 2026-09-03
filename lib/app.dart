import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/deep_link_provider.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Discarded on purpose — watching activates deepLinkProvider's
    // cold-/warm-start link listeners as early as possible, not for a
    // return value.
    ref.watch(deepLinkProvider);
    return MaterialApp.router(
      title: 'SharedTasks',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
