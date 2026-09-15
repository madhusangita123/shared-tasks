import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has an OS-level network connection —
/// issue #11 (US-08).
///
/// Firestore's own offline persistence means a write attempted during a
/// network outage doesn't throw — it resolves locally and is queued for
/// later sync, exactly like a normal successful write from the caller's
/// point of view. That's the right behavior for most apps, but this
/// issue's own product requirement is the opposite: an offline write must
/// be blocked outright, with a message, rather than silently queued. There
/// is no exception to catch for that — the write "succeeds" — so detecting
/// "offline" here needs an actual OS-level connectivity signal instead of
/// inferring it from a failed repository call.
///
/// Emits an initial value from [Connectivity.checkConnectivity] (mapped to
/// `true` unless the result is entirely [ConnectivityResult.none] — a
/// device can report more than one active interface, e.g. wifi and
/// ethernet, so "online" is "not the singleton none list", not "the list
/// contains wifi"), then continues with [Connectivity.onConnectivityChanged]
/// for every change after that.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    !(results.isEmpty || results.every((result) => result == ConnectivityResult.none));
