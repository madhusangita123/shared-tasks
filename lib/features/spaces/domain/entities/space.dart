import 'package:freezed_annotation/freezed_annotation.dart';

part 'space.freezed.dart';

/// A space — a named, ownable collection of tasks that can be private or
/// shared with any number of members.
///
/// Pure Dart — zero Flutter or Firebase imports. `data/` maps this to and
/// from Firestore manually (no `fromJson`/`toJson` here, matching the rest
/// of the codebase's entity convention).
@freezed
class Space with _$Space {
  const factory Space({
    required String id,
    required String name,
    required String ownerUid,
    required List<String> memberUids,
    required String inviteToken,
    required DateTime inviteExpiresAt,
    required DateTime createdAt,
  }) = _Space;
}
