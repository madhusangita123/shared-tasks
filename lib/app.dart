import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/providers/connectivity_provider.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/deep_link_provider.dart';
import 'package:shared_tasks/core/theme/app_theme.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/fcm_token_provider.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/foreground_notification_provider.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/notification_tap_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Discarded on purpose — watching activates deepLinkProvider's
    // cold-/warm-start link listeners as early as possible, not for a
    // return value. fcmTokenProvider/notificationTapProvider/
    // foregroundNotificationProvider (issue #12) are the same shape, for
    // the same reason.
    //
    // isOnlineProvider (issue #11) needs this too, for a different reason:
    // found via on-device testing that reading it lazily, only inside
    // _blockIfOffline at the moment of a mutation, means the very first
    // mutation attempt in a session sees it still AsyncLoading (the
    // connectivity stream hasn't delivered its first value yet) — which
    // fails open by design, so a genuinely offline first attempt wasn't
    // actually blocked. Watching it here starts that stream the instant
    // the app boots, so by the time a user can reach any mutation UI, it's
    // had real time to resolve.
    ref.watch(deepLinkProvider);
    ref.watch(fcmTokenProvider);
    ref.watch(notificationTapProvider);
    ref.watch(foregroundNotificationProvider);
    ref.watch(isOnlineProvider);
    return MaterialApp.router(
      title: 'SharedTasks',
      theme: AppTheme.light,
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
      routerConfig: router,
    );
  }
}
