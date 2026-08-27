import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Connects the Firebase SDKs to the local Firebase Emulator Suite instead
/// of the live `shared-tasks-dev` project.
///
/// Requires the emulators to be running first:
///   firebase emulators:start --only firestore,auth,functions
/// (or `./scripts/emulators.sh` — see repo root)
///
/// ⚠️ Platform-bound, not for plain `flutter test` unit/widget tests.
/// `Firebase.initializeApp()` needs real platform channels, which the Dart
/// VM used by regular `flutter test` unit/widget tests does not have. This
/// helper is for **integration tests** (`flutter test integration_test/` or
/// `flutter drive`, run against a real device/simulator/emulator) — per
/// `docs/ARCHITECTURE.md`'s testing strategy, integration tests are planned
/// for MVP 2.
///
/// Regular unit/widget tests in this project must keep mocking Firebase via
/// mocktail (see `CLAUDE.md` / `.ai-workflows/06-code-review-agent.md`:
/// "Never use real Firebase in tests — always mock") rather than call this.
Future<void> setupFirebaseEmulators() async {
  await Firebase.initializeApp();
  FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
}
