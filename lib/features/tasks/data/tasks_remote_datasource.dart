import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';

/// All Firestore calls for the tasks feature live here — nothing above this
/// layer touches Firestore directly.
///
/// Every write batches a bump of the parent `spaces/{spaceId}` doc's
/// [FirestoreConstants.updatedAt] alongside the task write itself. This
/// keeps [HomeRemoteDatasource]'s `watchUserSpaces` query — which orders by
/// that same field — reflecting task activity, so a space with a
/// just-added/edited/deleted task moves to the top of Home and its open
/// task count re-enriches on the next emission, without a second realtime
/// listener. Deliberate, approved design decision — not a bug.
class TasksRemoteDatasource {
  TasksRemoteDatasource({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Emits every task in [spaceId]'s `tasks` subcollection, re-emitting on
  /// every realtime change. Ordered by `createdAt` ascending — the screen
  /// does its own active/completed grouping, so no status filter is applied
  /// here; every task is returned.
  ///
  /// [_toTask] never throws — a single malformed doc is silently dropped
  /// from the emitted list rather than failing the whole mapping and
  /// turning every other task into an error state too.
  Stream<List<Task>> watchTasks(String spaceId) {
    return _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId)
        .collection(FirestoreConstants.tasksCollection)
        .orderBy(FirestoreConstants.createdAt)
        .snapshots()
        .map((snapshot) {
          final tasks = snapshot.docs.map((doc) => _toTask(doc, spaceId));
          return tasks.whereType<Task>().toList();
        });
  }

  /// Returns `null` — never throws — if [doc] is malformed in some
  /// unexpected way. One bad doc is dropped from the list rather than
  /// failing the entire snapshot mapping in [watchTasks].
  Task? _toTask(QueryDocumentSnapshot<Map<String, dynamic>> doc, String spaceId) {
    try {
      final data = doc.data();
      final createdAtValue = data[FirestoreConstants.createdAt];
      final updatedAtValue = data[FirestoreConstants.updatedAt];

      return Task(
        id: doc.id,
        spaceId: spaceId,
        title: data[FirestoreConstants.title] as String? ?? '',
        notes: data[FirestoreConstants.notes] as String?,
        status: TaskStatus.fromFirestoreValue(
          data[FirestoreConstants.status] as String? ?? '',
        ),
        assigneeUid: data[FirestoreConstants.assigneeUid] as String?,
        createdBy: data[FirestoreConstants.createdBy] as String? ?? '',
        createdAt: createdAtValue is Timestamp
            ? createdAtValue.toDate()
            : DateTime.now(),
        updatedAt: updatedAtValue is Timestamp
            ? updatedAtValue.toDate()
            : DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Adds a new `todo` task to [spaceId] and bumps the parent space's
  /// `updatedAt` in the same batch — see class doc comment.
  Future<void> addTask({
    required String spaceId,
    required String title,
    String? notes,
    required String createdBy,
  }) async {
    final batch = _firestore.batch();
    final spaceRef = _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId);
    final taskRef = spaceRef.collection(FirestoreConstants.tasksCollection).doc();

    batch.set(taskRef, {
      FirestoreConstants.title: title,
      FirestoreConstants.notes: notes,
      FirestoreConstants.status: FirestoreConstants.taskStatusTodo,
      FirestoreConstants.createdBy: createdBy,
      FirestoreConstants.createdAt: FieldValue.serverTimestamp(),
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });
    batch.update(spaceRef, {
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Updates [taskId]'s `title` and `notes`, and bumps the parent space's
  /// `updatedAt` in the same batch — see class doc comment.
  Future<void> updateTask({
    required String spaceId,
    required String taskId,
    required String title,
    String? notes,
  }) async {
    final batch = _firestore.batch();
    final spaceRef = _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId);
    final taskRef = spaceRef
        .collection(FirestoreConstants.tasksCollection)
        .doc(taskId);

    batch.update(taskRef, {
      FirestoreConstants.title: title,
      FirestoreConstants.notes: notes,
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });
    batch.update(spaceRef, {
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deletes [taskId] from [spaceId], and bumps the parent space's
  /// `updatedAt` in the same batch — see class doc comment.
  Future<void> deleteTask({
    required String spaceId,
    required String taskId,
  }) async {
    final batch = _firestore.batch();
    final spaceRef = _firestore
        .collection(FirestoreConstants.spacesCollection)
        .doc(spaceId);
    final taskRef = spaceRef
        .collection(FirestoreConstants.tasksCollection)
        .doc(taskId);

    batch.delete(taskRef);
    batch.update(spaceRef, {
      FirestoreConstants.updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
