import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/core/entities/member_avatar.dart';
import 'package:shared_tasks/features/spaces/domain/entities/space.dart';
import 'package:uuid/uuid.dart';

/// All Firestore calls for the spaces feature live here — nothing above
/// this layer touches Firestore directly.
class SpacesRemoteDatasource {
  SpacesRemoteDatasource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

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
}
