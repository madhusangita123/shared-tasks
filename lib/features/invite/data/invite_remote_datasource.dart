import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';
import 'package:uuid/uuid.dart';

/// Thrown by [InviteRemoteDatasource.regenerateInvite] when [callerUid]
/// isn't the space's owner. `firestore.rules` itself doesn't (and can't,
/// without a dedicated Cloud Function) restrict this write to the owner
/// specifically — it allows any member, the same blanket rule every space
/// update goes through (see #6). This is an application-level check on top
/// of that, so "owner only" is actually enforced somewhere, not just
/// implied by which button a screen happens to show.
class PermissionDeniedException implements Exception {
  const PermissionDeniedException();
}

/// All Firestore and Cloud Functions calls for the invite feature live
/// here — nothing above this layer touches either directly.
class InviteRemoteDatasource {
  InviteRemoteDatasource({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Writes a new invite token + expiry onto the existing `spaces/{spaceId}`
  /// doc, immediately invalidating the previous token (`joinSpaceByToken`
  /// looks up a space by exact token match).
  ///
  /// Throws [PermissionDeniedException] if [callerUid] isn't the space's
  /// `ownerUid` — see that class's doc comment for why this check lives
  /// here rather than relying solely on `firestore.rules`.
  ///
  /// Bumps [FirestoreConstants.updatedAt] for the same reason
  /// [SpacesRemoteDatasource.createSpace] does — keeps Home's ordering and
  /// re-enrichment live, and is generally correct practice for "this space
  /// was just modified".
  Future<Invite> regenerateInvite({
    required String spaceId,
    required String callerUid,
  }) async {
    final docRef = _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId);

    final snapshot = await docRef.get();
    final ownerUid = snapshot.data()?[FirestoreConstants.ownerUid] as String?;
    if (ownerUid != callerUid) {
      throw const PermissionDeniedException();
    }

    final inviteToken = const Uuid().v4();
    final inviteExpiresAt = DateTime.now().add(
      AppConstants.inviteLinkValidity,
    );

    await docRef.update({
      FirestoreConstants.inviteToken: inviteToken,
      FirestoreConstants.inviteExpiresAt: Timestamp.fromDate(
        inviteExpiresAt,
      ),
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });

    return Invite(
      spaceId: spaceId,
      token: inviteToken,
      expiresAt: inviteExpiresAt,
    );
  }

  /// Calls the `joinSpaceByToken` callable with [token], returning the
  /// joined space's id from its `{ spaceId }` response.
  Future<String> joinSpace(String token) async {
    final callable = _functions.httpsCallable('joinSpaceByToken');
    final result = await callable.call<Map<String, dynamic>>({
      'token': token,
    });
    return result.data['spaceId'] as String;
  }
}
