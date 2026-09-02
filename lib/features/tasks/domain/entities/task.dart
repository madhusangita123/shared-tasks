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
    // Unused until issue #9 (assignment) — carried through so the entity
    // shape doesn't need to change when that lands.
    String? assigneeUid,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Task;
}
