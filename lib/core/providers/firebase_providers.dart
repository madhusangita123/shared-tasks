import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared Firebase infrastructure providers — matches
/// docs/ARCHITECTURE.md's documented pattern. Lives in `core/` since more
/// than one feature (`home`, `spaces`) now depends on it.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Callable Cloud Functions client — used by the `invite` feature to call
/// `joinSpaceByToken` (see `functions/src/joinSpaceByToken.ts`).
final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});
