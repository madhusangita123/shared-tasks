import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:uuid/uuid.dart';

/// All Firestore and Cloud Functions calls for the spaces feature live
/// here — nothing above this layer touches either directly.
class SpacesRemoteDatasource {
  SpacesRemoteDatasource({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Creates a new `spaces/{spaceId}` doc owned by [ownerUid], with
  /// [ownerUid] as its sole initial member.
  ///
  /// Writes [FirestoreConstants.updatedAt] alongside `createdAt` even
  /// though nothing has "updated" yet. [HomeRemoteDatasource]'s
  /// `watchUserSpaces` query does `.orderBy(FirestoreConstants.updatedAt,
  /// descending: true)`, and Firestore's `orderBy` implicitly filters out
  /// documents missing that field entirely — a space created without
  /// `updatedAt` would silently never appear on the Home screen.
  Future<Space> createSpace({
    required String name,
    required String ownerUid,
  }) async {
    final docRef = _firestore.collection(FirestoreConstants.spacesCollection).doc();
    final inviteToken = const Uuid().v4();
    final inviteExpiresAt = DateTime.now().add(
      AppConstants.inviteLinkValidity,
    );

    await docRef.set({
      FirestoreConstants.name: name,
      FirestoreConstants.ownerUid: ownerUid,
      FirestoreConstants.memberUids: [ownerUid],
      FirestoreConstants.inviteToken: inviteToken,
      FirestoreConstants.inviteExpiresAt: Timestamp.fromDate(inviteExpiresAt),
      FirestoreConstants.createdAt: FieldValue.serverTimestamp(),
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });

    return Space(
      id: docRef.id,
      name: name,
      ownerUid: ownerUid,
      memberUids: [ownerUid],
      inviteToken: inviteToken,
      inviteExpiresAt: inviteExpiresAt,
      // Client-side approximation — the server timestamp isn't resolved
      // yet at this point, same convention HomeRemoteDatasource uses
      // elsewhere for pending timestamps.
      createdAt: DateTime.now(),
    );
  }

  /// Emits [spaceId]'s current [Space] on every realtime change, or `null`
  /// if the doc doesn't exist or is malformed — never throws, matching
  /// [HomeRemoteDatasource]'s malformed-doc isolation convention.
  Stream<Space?> watchSpace(String spaceId) {
    return _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId)
        .snapshots()
        .map(_toSpace);
  }

  Space? _toSpace(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final data = doc.data();
      if (data == null) return null;

      final inviteExpiresAtValue = data[FirestoreConstants.inviteExpiresAt];
      final createdAtValue = data[FirestoreConstants.createdAt];

      return Space(
        id: doc.id,
        name: data[FirestoreConstants.name] as String? ?? '',
        ownerUid: data[FirestoreConstants.ownerUid] as String? ?? '',
        memberUids: List<String>.from(
          data[FirestoreConstants.memberUids] as List<dynamic>? ?? const [],
        ),
        inviteToken: data[FirestoreConstants.inviteToken] as String? ?? '',
        inviteExpiresAt: inviteExpiresAtValue is Timestamp
            ? inviteExpiresAtValue.toDate()
            : DateTime.now(),
        createdAt: createdAtValue is Timestamp
            ? createdAtValue.toDate()
            : DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches `publicProfiles/{uid}` once per member, in parallel via
  /// [Future.wait]. Reads the public-profile mirror (displayName + photoUrl
  /// only) rather than `users/{uid}` — this feature only needs
  /// display-facing fields, and `users/{uid}` also holds `email`/`fcmToken`
  /// which are owner-only readable (see firestore.rules). A single member
  /// lookup failing (missing or unreadable doc) skips just that member's
  /// avatar rather than breaking the whole member list.
  Future<List<MemberAvatar>> getMemberAvatars(List<String> memberUids) async {
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

  /// Open (not-done) task count for [spaceId], via a one-shot aggregate
  /// `.count()` query — the exact same shape as
  /// `HomeRemoteDatasource._openTaskCount`, duplicated here rather than
  /// shared because nothing in `features/spaces` may import
  /// `features/tasks` or `features/home` (no cross-feature imports exist
  /// anywhere in this codebase).
  ///
  /// Returns 0 — never throws — if the subcollection is empty, missing, or
  /// the query fails for any reason. The caller (the delete confirmation)
  /// must never be blocked by a count it could not get.
  Future<int> countOpenTasks({required String spaceId}) async {
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

  /// Calls the `deleteSpace` callable, which deletes every task under
  /// `spaces/{spaceId}/tasks` and then the space document itself.
  ///
  /// Deliberately not done client-side: Firestore doesn't cascade, so the
  /// task subcollection has to be deleted first, and a client that dies
  /// mid-sequence would leave a half-deleted space visible to the *other*
  /// members too. The owner-only check also lives in the function — see
  /// `functions/src/deleteSpace.ts`.
  ///
  /// Throws [FirebaseFunctionsException] on any `HttpsError` the function
  /// raises (notably `permission-denied` for a non-owner caller);
  /// [SpacesRepositoryImpl] maps those to failures.
  Future<void> deleteSpace(String spaceId) async {
    final callable = _functions.httpsCallable('deleteSpace');
    await callable.call<Map<String, dynamic>>({'spaceId': spaceId});
  }
}
