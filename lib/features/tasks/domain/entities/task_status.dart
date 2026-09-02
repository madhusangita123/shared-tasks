import 'package:shared_tasks/core/constants/firestore_constants.dart';

/// A task's lifecycle status. Cycles todo → in_progress → done → todo
/// (see US-07).
///
/// Pure Dart — zero Flutter or Firebase imports. References
/// [FirestoreConstants]'s plain string values only, not `cloud_firestore`
/// itself.
enum TaskStatus {
  todo,
  inProgress,
  done;

  /// The exact string stored in Firestore's `status` field for this value.
  String get firestoreValue => switch (this) {
    TaskStatus.todo => FirestoreConstants.taskStatusTodo,
    TaskStatus.inProgress => FirestoreConstants.taskStatusInProgress,
    TaskStatus.done => FirestoreConstants.taskStatusDone,
  };

  /// Parses a Firestore `status` string back into a [TaskStatus]. Never
  /// throws — an unrecognized value defaults to [TaskStatus.todo], matching
  /// this codebase's "never throw from data mapping" convention.
  static TaskStatus fromFirestoreValue(String value) {
    return switch (value) {
      FirestoreConstants.taskStatusInProgress => TaskStatus.inProgress,
      FirestoreConstants.taskStatusDone => TaskStatus.done,
      _ => TaskStatus.todo,
    };
  }
}
