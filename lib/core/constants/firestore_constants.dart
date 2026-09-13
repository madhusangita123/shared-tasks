/// Firestore collection and field name strings.
///
/// Never hardcode a collection or field name string anywhere else — always
/// reference a constant from this class so a rename only touches one file.
abstract final class FirestoreConstants {
  // Collections
  static const usersCollection = 'users';
  // Small, world-readable-to-authenticated-users mirror of the
  // display-facing subset of a user's profile (displayName + photoUrl
  // only). Exists so avatars (home cards, task assignees, invite flow) can
  // be shown without granting broad read access to `users/{uid}`, which
  // also holds `email` and `fcmToken` — see firestore.rules.
  static const publicProfilesCollection = 'publicProfiles';
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
  // Who performed the assignment (issue #12) — distinct from assigneeUid,
  // who was assigned. Drives the notification copy's "[Name] assigned..."
  // wording, which needs the assigner's name, not just the assignee's.
  static const assignedByUid = 'assignedByUid';
  static const createdBy = 'createdBy';

  // Task status values (see docs/ARCHITECTURE.md — Firestore data model).
  static const taskStatusTodo = 'todo';
  static const taskStatusInProgress = 'in_progress';
  static const taskStatusDone = 'done';
}
