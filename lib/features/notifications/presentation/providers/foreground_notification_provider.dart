import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/notification_tap_provider.dart';

/// The [ScaffoldMessengerState] key `MaterialApp.router` is built with (see
/// `App.build`) — [foregroundNotificationProvider] needs a way to show a
/// [SnackBar] from outside the widget tree (it's a plain side-effect
/// provider, not a widget, so it has no [BuildContext] of its own), and a
/// global key on the app's single [ScaffoldMessenger] is the standard way
/// to do that. A `Provider` (not a bare top-level `GlobalKey`) so it's
/// created exactly once per app run, the same as everything else here.
final scaffoldMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);

/// Shows a [SnackBar] for a push notification that arrives while the app is
/// already in the foreground (issue #12, US-09).
///
/// [FirebaseMessaging] only asks the OS to show a system-tray notification
/// when the app is backgrounded or not running at all — a message that
/// arrives while the app is in the foreground is delivered straight to the
/// app instead, via [FirebaseMessaging.onMessage], with no UI of its own.
/// Without this, a foreground user who gets assigned a task while looking
/// at the app would never know — silently defeating the whole point of
/// US-09 ("so I always know who's handling what") for exactly the moment
/// they're most likely to be looking at their phone. This is the
/// foreground counterpart to [notificationTapProvider]'s background/
/// terminated handling — together they cover every state the app can be
/// in when a notification arrives.
///
/// A side-effect-only `Provider<void>`, the same shape as `deepLinkProvider`
/// — watch it once (see `App.build`) so its side effect starts as early as
/// possible; its return value is never used.
///
/// The SnackBar's "View" action reuses [extractTaskDeepLink] and the same
/// `AppRoutes.taskListPath(..., openTaskId: ...)` navigation
/// [notificationTapProvider] uses for a tap — so whether the notification
/// was tapped from the system tray or its in-app SnackBar action, it lands
/// in the same place.
final foregroundNotificationProvider = Provider<void>((ref) {
  final subscription = FirebaseMessaging.onMessage.listen((message) {
    final body = message.notification?.body;
    if (body == null || body.isEmpty) return;

    final key = ref.read(scaffoldMessengerKeyProvider);
    final messengerState = key.currentState;
    // The key's own `currentContext` (not a param this provider otherwise
    // has access to — it isn't a widget) is what makes this bar
    // theme-aware rather than a hardcoded color guess that would go wrong
    // the moment the app grows a dark theme.
    final context = key.currentContext;
    if (messengerState == null || context == null || !context.mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

    final deepLink = extractTaskDeepLink(message.data);
    messengerState
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: colorScheme.primaryContainer,
          content: Row(
            children: [
              Icon(
                Icons.notifications_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  body,
                  style: TextStyle(color: colorScheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
          action: deepLink == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  textColor: colorScheme.primary,
                  onPressed: () {
                    final router = ref.read(routerProvider);
                    // Same `go(Home)` + `push(taskList)` reasoning as
                    // notificationTapProvider — a bare `go` here would
                    // still flatten whatever was on the stack beneath
                    // wherever the user happened to be when this arrived.
                    router.go(AppRoutes.home);
                    router.push(
                      AppRoutes.taskListPath(
                        deepLink.spaceId,
                        openTaskId: deepLink.taskId,
                      ),
                    );
                  },
                ),
        ),
      );
  }, onError: (Object _) {});

  ref.onDispose(subscription.cancel);
});
