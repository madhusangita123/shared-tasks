import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_tasks/features/home/domain/entities/member_avatar.dart';

part 'home_space.freezed.dart';

/// A home-screen read projection of a space.
///
/// Deliberately not named `Space` — that name is reserved for the future
/// `spaces` feature's own richer entity. This is a home-scoped projection:
/// just enough to render a space card in the all-spaces list.
///
/// Pure Dart — zero Flutter or Firebase imports. `data/` builds this from
/// the `spaces/{spaceId}` doc plus per-space enrichment (open task count,
/// member avatars).
@freezed
class HomeSpace with _$HomeSpace {
  const HomeSpace._();

  const factory HomeSpace({
    required String id,
    required String name,
    required List<String> memberUids,
    required int openTaskCount,
    required DateTime updatedAt,
    required List<MemberAvatar> memberAvatars,
  }) = _HomeSpace;

  /// A space is shared once it has more than one member. Private spaces
  /// carry an empty [memberAvatars] list and render no avatars.
  bool get isShared => memberUids.length > 1;
}
