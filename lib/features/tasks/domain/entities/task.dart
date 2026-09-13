import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_tasks/features/tasks/domain/entities/task_status.dart';

part 'task.freezed.dart';

/// A single task within a space's task list.
///
/// Pure Dart — zero Flutter or Firebase imports. `data/` maps this to and
/// from Firestore manually (no `fromJson`/`toJson` here, matching
/// [Space]/`HomeSpace`/`AppUser`'s entity convention).
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String spaceId,
    required String title,
    String? notes,
    required TaskStatus status,
    String? assigneeUid,
    // Who performed the assignment (issue #12) — distinct from
    // assigneeUid, who was assigned. Null until a task has ever been
    // assigned. Nullable/optional like assigneeUid, for the same reason:
    // there's no assigner until there's an assignment.
    String? assignedByUid,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Task;
}
