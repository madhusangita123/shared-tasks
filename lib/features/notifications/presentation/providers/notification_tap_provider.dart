import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

/// Extracts the `(spaceId, taskId)` pair `onTaskAssigned` (Cloud Functions)
/// puts in a notification's `data` payload, or `null` if either is missing
/// — a notification with no deep-link data (shouldn't happen for anything
/// this app itself sends, but the AC doesn't require crashing over a
/// malformed payload either).
({String spaceId, String taskId})? extractTaskDeepLink(Map<String, dynamic> data) {
  final spaceId = data['spaceId'] as String?;
  final taskId = data['taskId'] as String?;
  if (spaceId == null || spaceId.isEmpty || taskId == null || taskId.isEmpty) {
    return null;
  }
  return (spaceId: spaceId, taskId: taskId);
}

/// Deep-links a tapped push notification straight to its task's detail
/// sheet (issue #12, US-09 — "Tapping a notification deep-links directly
/// to that task's detail sheet").
///
/// A side-effect-only `Provider<void>`, the same shape as `deepLinkProvider`
/// (`core/router/deep_link_provider.dart`) — watch it once (see `App.build`)
/// so its side effect starts as early as possible; its return value is
/// never used.
///
/// Mirrors `deepLinkProvider`'s exact dual-path reasoning, for the same
/// underlying reason: `firebase_messaging` surfaces a tapped notification
/// two different ways depending on *when* the tap happens, and both must be
/// handled for a tap to reliably deep-link:
///
/// - **Cold start** — the app wasn't running and the OS launched it via the
///   notification tap. That notification is only available via
///   [FirebaseMessaging.getInitialMessage], a one-shot
///   `Future<RemoteMessage?>` checked once at startup; it is *not* replayed
///   on [FirebaseMessaging.onMessageOpenedApp].
/// - **Warm start** — the app was already running (foreground or
///   background) when the notification was tapped. That arrives on the
///   static [FirebaseMessaging.onMessageOpenedApp], a live
///   `Stream<RemoteMessage>`; it is never returned by
///   [FirebaseMessaging.getInitialMessage].
///
/// Every messaging call is wrapped so a failure here (messaging
/// unavailable, malformed payload) never crashes the app — it just means
/// no deep-link happens, same as any other notification-related failure
/// this issue's other providers guard against.
final notificationTapProvider = Provider<void>((ref) {
  void openDeepLink(RemoteMessage? message) {
    if (message == null) return;
    final deepLink = extractTaskDeepLink(message.data);
    if (deepLink == null) return;
    final router = ref.read(routerProvider);
    // `go` alone would replace the whole navigation stack with just the
    // task list — fine on a warm start where Home was already on the
    // stack, but on a cold start (a tapped notification is the very first
    // thing that runs) it's the *only* thing on the stack, leaving no
    // back path to Home at all. Same fix as JoinSpaceScreen's success
    // navigation: `go` to Home first to establish it as the stack's root,
    // then `push` the task list on top, so the back arrow always works
    // regardless of cold vs. warm start.
    router.go(AppRoutes.home);
    router.push(
      AppRoutes.taskListPath(deepLink.spaceId, openTaskId: deepLink.taskId),
    );
  }

  // Cold start: the app was launched fresh by tapping the notification.
  FirebaseMessaging.instance
      .getInitialMessage()
      .then(openDeepLink)
      .catchError((Object _) {});

  // Warm start: the app was already running when the notification was
  // tapped.
  final subscription = FirebaseMessaging.onMessageOpenedApp.listen(
    openDeepLink,
    onError: (Object _) {},
  );
  ref.onDispose(subscription.cancel);
});
