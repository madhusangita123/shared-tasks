import 'package:freezed_annotation/freezed_annotation.dart';

part 'member_avatar.freezed.dart';

/// A lightweight member projection used to render avatars on a shared
/// space's home card.
///
/// Pure Dart — zero Flutter or Firebase imports. `data/` maps this to and
/// from Firestore's `users/{uid}` doc.
@freezed
class MemberAvatar with _$MemberAvatar {
  const factory MemberAvatar({
    required String uid,
    required String displayName,
    String? photoUrl,
  }) = _MemberAvatar;
}
