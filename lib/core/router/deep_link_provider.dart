import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/core/router/app_router.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

/// Extracts the invite token from a `sharedtasks://join/{token}` deep link.
///
/// Returns the first path segment when [uri]'s host is `join` and it has at
/// least one path segment, otherwise `null` (any other host, or a bare
/// `sharedtasks://join` with no token).
String? extractJoinToken(Uri uri) {
  if (uri.host != 'join' || uri.pathSegments.isEmpty) return null;
  return uri.pathSegments.first;
}

/// Activates deep-link handling for `sharedtasks://join/{token}` invite
/// links (US-04 / issue #29).
///
/// `app_links` surfaces an incoming link in one of two distinct ways
/// depending on *when* it arrives, and both must be handled for a link tap
/// to reliably open [AppRoutes.joinSpacePath]:
///
/// - **Cold start** — the app was not running and the OS launched it
///   directly from the link tap. That link is only available via
///   [AppLinks.getInitialLink], a one-shot `Future<Uri?>` checked once at
///   startup; it is *not* replayed on [AppLinks.uriLinkStream].
/// - **Warm start** — the app was already running (foreground or
///   background) when the link was tapped. That link arrives on
///   [AppLinks.uriLinkStream], a live `Stream<Uri>`; it is never returned by
///   [AppLinks.getInitialLink].
///
/// Reading only one of the two would miss half of real-world invite taps,
/// so this provider wires up both against the same handler.
///
/// This is deliberately *not* the only path a deep link can take to
/// [AppRoutes.joinSpacePath] — Flutter's own built-in deep-link routing
/// (left enabled, its platform default, on both Android and iOS) can also
/// deliver the raw external URI straight into `routerProvider`, and does
/// so reliably for cases this plugin's `getInitialLink` misses (notably,
/// iOS cold starts for apps using the Scene-based lifecycle — confirmed by
/// on-device testing during #29's build). `app_router.dart`'s top-level
/// `redirect` normalizes a raw `sharedtasks://` URI into an app-relative
/// path regardless of which mechanism delivered it, so the two are
/// complementary, not competing: whichever fires, the outcome is the same.
///
/// This provider has no return value of interest — it exists purely for its
/// side effect. Watch it once (see `App.build`) so the side effect starts
/// as early as possible.
final deepLinkProvider = Provider<void>((ref) {
  final appLinks = AppLinks();

  Future<void> handleLink(Uri? uri) async {
    if (uri == null) return;
    final token = extractJoinToken(uri);
    if (token == null) return;
    ref.read(routerProvider).go(AppRoutes.joinSpacePath(token));
  }

  // Cold start: the app was launched fresh by tapping the link.
  appLinks.getInitialLink().then(handleLink);

  // Warm start: the app was already running when the link was tapped.
  final subscription = appLinks.uriLinkStream.listen(handleLink);
  ref.onDispose(subscription.cancel);
});
