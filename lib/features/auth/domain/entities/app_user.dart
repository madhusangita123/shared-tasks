import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The signed-in user, sourced from their Google profile.
///
/// Pure Dart — zero Flutter or Firebase imports. `data/` maps this to and
/// from Firebase types.
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String displayName,
    required String email,
    String? photoUrl,
    String? fcmToken,
  }) = _AppUser;
}
