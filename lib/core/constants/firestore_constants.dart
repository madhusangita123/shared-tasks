/// Firestore collection and field name strings.
///
/// Never hardcode a collection or field name string anywhere else — always
/// reference a constant from this class so a rename only touches one file.
abstract final class FirestoreConstants {
  // Collections
  static const usersCollection = 'users';
  static const spacesCollection = 'spaces';
  static const tasksCollection = 'tasks';

  // Shared fields
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';

  // users/{uid}
  static const displayName = 'displayName';
  static const email = 'email';
  static const photoUrl = 'photoUrl';
  static const fcmToken = 'fcmToken';

  // spaces/{spaceId}
  static const name = 'name';
  static const ownerUid = 'ownerUid';
  static const memberUids = 'memberUids';
  static const inviteToken = 'inviteToken';
  static const inviteExpiresAt = 'inviteExpiresAt';

  // spaces/{spaceId}/tasks/{taskId}
  static const title = 'title';
  static const notes = 'notes';
  static const status = 'status';
  static const assigneeUid = 'assigneeUid';
  static const createdBy = 'createdBy';
}
