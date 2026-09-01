import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/features/home/domain/entities/home_space.dart';
import 'package:shared_tasks/features/home/domain/entities/member_avatar.dart';

/// All Firestore calls for the home feature live here — nothing above this
/// layer touches Firestore directly.
class HomeRemoteDatasource {
  HomeRemoteDatasource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Emits every space [uid] owns or is a member of, ordered by most
  /// recently updated, and re-emits on every realtime change to the base
  /// `spaces` query.
  ///
  /// Each emission is enriched per-space with an open task count and (for
  /// shared spaces) member avatars before being emitted — see
  /// [_toHomeSpace]. Enrichment fetches are one-shot (`.get()`/`.count()`),
  /// not nested realtime listeners, so a change to a task or a member's
  /// profile is picked up on the next `spaces` snapshot rather than
  /// instantly — an accepted trade-off since `tasks/` doesn't exist yet.
  ///
  /// [_toHomeSpace] never throws — a single malformed doc is silently
  /// dropped from the emitted list rather than failing the whole
  /// `Future.wait` and turning every other space's card into an error
  /// state too.
  Stream<List<HomeSpace>> watchUserSpaces(String uid) {
    return _firestore
        .collection(FirestoreConstants.spacesCollection)
        .where(FirestoreConstants.memberUids, arrayContains: uid)
        .orderBy(FirestoreConstants.updatedAt, descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final spaces = await Future.wait(snapshot.docs.map(_toHomeSpace));
          return spaces.whereType<HomeSpace>().toList();
        });
  }

  /// Returns `null` — never throws — if [doc] is malformed in some
  /// unexpected way (e.g. `memberUids` isn't a list). One bad doc is
  /// dropped from the list rather than failing the entire snapshot's
  /// [Future.wait] in [watchUserSpaces], which would otherwise turn every
  /// other (perfectly fine) space's card into an error state too.
  Future<HomeSpace?> _toHomeSpace(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final data = doc.data();
      final memberUids = List<String>.from(
        data[FirestoreConstants.memberUids] as List<dynamic>? ?? const [],
      );

      final enrichment = await Future.wait([
        _openTaskCount(doc.id),
        memberUids.length > 1
            ? _memberAvatars(memberUids)
            : Future.value(const <MemberAvatar>[]),
      ]);

      final updatedAtValue = data[FirestoreConstants.updatedAt];
      final updatedAt = updatedAtValue is Timestamp
          ? updatedAtValue.toDate()
          : DateTime.now();

      return HomeSpace(
        id: doc.id,
        name: data[FirestoreConstants.name] as String? ?? '',
        memberUids: memberUids,
        openTaskCount: enrichment[0] as int,
        updatedAt: updatedAt,
        memberAvatars: enrichment[1] as List<MemberAvatar>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Open (not-done) task count via a one-shot aggregate `.count()` query —
  /// deliberately not `.snapshots()`. Avoids one realtime listener per
  /// space per emission, since `tasks/` doesn't exist yet to validate true
  /// realtime counting against (see design decision in issue #16).
  ///
  /// Returns 0 — never throws — if the subcollection is empty, missing, or
  /// the query fails for any reason.
  Future<int> _openTaskCount(String spaceId) async {
    try {
      final aggregate = await _firestore
          .collection(FirestoreConstants.spacesCollection)
          .doc(spaceId)
          .collection(FirestoreConstants.tasksCollection)
          .where(
            FirestoreConstants.status,
            isNotEqualTo: FirestoreConstants.taskStatusDone,
          )
          .count()
          .get();
      return aggregate.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches `publicProfiles/{uid}` once per member, in parallel via
  /// [Future.wait]. Reads the public-profile mirror (displayName + photoUrl
  /// only) rather than `users/{uid}` — the home feature only needs
  /// display-facing fields, and `users/{uid}` also holds `email`/`fcmToken`
  /// which are owner-only readable (see firestore.rules). A single member
  /// lookup failing (missing or unreadable doc) skips just that member's
  /// avatar rather than breaking the whole space card.
  Future<List<MemberAvatar>> _memberAvatars(List<String> memberUids) async {
    final avatars = await Future.wait(memberUids.map(_memberAvatar));
    return avatars.whereType<MemberAvatar>().toList();
  }

  Future<MemberAvatar?> _memberAvatar(String uid) async {
    try {
      final doc = await _firestore
          .collection(FirestoreConstants.publicProfilesCollection)
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null) return null;
      return MemberAvatar(
        uid: uid,
        displayName: data[FirestoreConstants.displayName] as String? ?? '',
        photoUrl: data[FirestoreConstants.photoUrl] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
