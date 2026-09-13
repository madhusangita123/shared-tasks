import 'package:firebase_messaging/firebase_messaging.dart';

/// Requests notification permission (issue #12, US-09 — "Notification
/// permission requested after user's first space is created or joined").
///
/// A plain top-level function, not a provider — unlike `fcmTokenProvider`/
/// `notificationTapProvider` (which run as ambient side effects watched
/// once at app root), this needs to fire at one specific imperative moment:
/// right after `CreateSpaceScreen`/`JoinSpaceScreen` successfully create or
/// join the user's first space. Screens call it directly rather than
/// through a repository — there's no domain data involved, just a native
/// OS permission prompt, so this doesn't fit the `Result<T>`/repository
/// pattern that Firestore/Firebase Auth calls elsewhere in this codebase
/// use.
///
/// Wrapped in try/catch so a platform without messaging configured (no
/// APNs entitlement, simulator, no Google Play Services, ...) never
/// crashes the app — the AC requires the app to "function normally" either
/// way. [FirebaseMessaging.requestPermission] itself already never prompts
/// twice — the OS remembers a prior grant/denial and returns it directly on
/// every subsequent call — which is what satisfies "no repeated permission
/// prompts" without this function needing to track that itself.
Future<void> requestNotificationPermission() async {
  try {
    await FirebaseMessaging.instance.requestPermission();
  } catch (_) {
    // Messaging unavailable — leave the app functioning normally, per the
    // AC, rather than surface an error the user can't act on.
  }
}
