import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
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
}
