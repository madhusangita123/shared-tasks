import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';

void main() {
  group('FirestoreConstants', () {
    test('collection names are lowercase and non-empty', () {
      expect(FirestoreConstants.usersCollection, 'users');
      expect(FirestoreConstants.spacesCollection, 'spaces');
      expect(FirestoreConstants.tasksCollection, 'tasks');
    });

    test('task field names match the schema', () {
      expect(FirestoreConstants.title, 'title');
      expect(FirestoreConstants.notes, 'notes');
      expect(FirestoreConstants.status, 'status');
      expect(FirestoreConstants.assigneeUid, 'assigneeUid');
      expect(FirestoreConstants.createdBy, 'createdBy');
    });

    test('space field names match the schema', () {
      expect(FirestoreConstants.name, 'name');
      expect(FirestoreConstants.ownerUid, 'ownerUid');
      expect(FirestoreConstants.memberUids, 'memberUids');
      expect(FirestoreConstants.inviteToken, 'inviteToken');
      expect(FirestoreConstants.inviteExpiresAt, 'inviteExpiresAt');
    });

    test('all field name constants are unique strings', () {
      final values = [
        FirestoreConstants.usersCollection,
        FirestoreConstants.spacesCollection,
        FirestoreConstants.tasksCollection,
        FirestoreConstants.createdAt,
        FirestoreConstants.updatedAt,
        FirestoreConstants.displayName,
        FirestoreConstants.email,
        FirestoreConstants.photoUrl,
        FirestoreConstants.fcmToken,
        FirestoreConstants.name,
        FirestoreConstants.ownerUid,
        FirestoreConstants.memberUids,
        FirestoreConstants.inviteToken,
        FirestoreConstants.inviteExpiresAt,
        FirestoreConstants.title,
        FirestoreConstants.notes,
        FirestoreConstants.status,
        FirestoreConstants.assigneeUid,
        FirestoreConstants.createdBy,
      ];

      expect(values.toSet(), hasLength(values.length));
      expect(values.every((value) => value.isNotEmpty), isTrue);
    });
  });
}
