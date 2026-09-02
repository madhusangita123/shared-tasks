import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared Firebase infrastructure providers — matches
/// docs/ARCHITECTURE.md's documented pattern. Lives in `core/` since more
/// than one feature (`home`, `spaces`) now depends on it.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
