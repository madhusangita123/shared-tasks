import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/presentation/providers/auth_provider.dart';

/// Keeps `users/{uid}.fcmToken` current for the signed-in user (issue #12,
/// US-09 — "FCM token stored in `users/{uid}.fcmToken` and kept current on
/// each sign-in").
///
/// A side-effect-only `Provider<void>`, the same shape as `deepLinkProvider`
/// (`core/router/deep_link_provider.dart`) — watch it once (see `App.build`)
/// so its side effect starts as early as possible; its return value is never
/// used.
///
/// `ref.listen(authStateProvider, ...)` — not `ref.watch` — drives this:
/// [fcmTokenProvider] itself must not rebuild every time auth state
/// changes (that would tear down and recreate the `onTokenRefresh`
/// subscription below for no reason); it only needs to *react* to each
/// change, exactly like `routerProvider`'s own `ref.listen(authStateProvider,
/// ...)` for its refresh notifier.
///
/// On every transition to a signed-in user, this:
///   1. Fetches the current token via `FirebaseMessaging.instance.getToken()`
///      and writes it via `AuthRepository.updateFcmToken`.
///   2. (Re)subscribes to `FirebaseMessaging.instance.onTokenRefresh` so a
///      later token rotation (the OS can reissue a token at any time, not
///      just at sign-in) is written too — cancelling any previous
///      subscription first, so signing out and back in as a different user
///      doesn't leave a stale subscription writing to the wrong uid.
///
/// On sign-out, the subscription is cancelled and nothing further happens —
/// there is no signed-out uid to write a token for, and the doc's existing
/// value is left as-is (harmless: `onTaskAssigned` only ever reads a token
/// for a uid that's still a space member, and a stale token for a
/// since-signed-out session just fails to deliver silently, per that
/// function's own per-token failure handling).
///
/// Every messaging call is wrapped in try/catch — this must never crash the
/// app if messaging is unavailable (no APNs entitlement, simulator, no
/// Google Play Services, ...) or if notification permission was denied; the
/// AC is explicit that "if permission denied, app functions normally".
final fcmTokenProvider = Provider<void>((ref) {
  StreamSubscription<String>? refreshSubscription;

  Future<void> writeToken(String uid, String? token) async {
    if (token == null) return;
    await ref.read(authRepositoryProvider).updateFcmToken(uid: uid, token: token);
  }

  Future<void> syncToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await writeToken(uid, token);
    } catch (_) {
      // Messaging unavailable, or the user hasn't granted permission yet —
      // leave fcmToken as-is rather than crash. requestNotificationPermission
      // (called from CreateSpaceScreen/JoinSpaceScreen) is what actually
      // prompts; this provider only ever reacts to whatever state results.
    }
  }

  void startTokenRefreshListener(String uid) {
    refreshSubscription?.cancel();
    try {
      refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => writeToken(uid, token),
        onError: (Object _) {},
      );
    } catch (_) {
      // As above — messaging unavailable is not a crash.
    }
  }

  ref.listen<AsyncValue<AppUser?>>(
    authStateProvider,
    (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        refreshSubscription?.cancel();
        refreshSubscription = null;
        return;
      }
      syncToken(user.id);
      startTokenRefreshListener(user.id);
    },
    fireImmediately: true,
  );

  ref.onDispose(() => refreshSubscription?.cancel());
});
