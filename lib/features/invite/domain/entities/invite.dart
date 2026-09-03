import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite.freezed.dart';

/// The result of (re)generating a space's invite — the token and expiry
/// currently stored on `spaces/{spaceId}`, plus the [spaceId] it belongs to.
///
/// Pure Dart — zero Flutter or Firebase imports, matching [Space]'s entity
/// convention (no `fromJson`/`toJson` here; `data/` maps to and from
/// Firestore manually).
@freezed
class Invite with _$Invite {
  const Invite._();

  const factory Invite({
    required String spaceId,
    required String token,
    required DateTime expiresAt,
  }) = _Invite;

  /// The `sharedtasks://join/{token}` deep link recipients tap to join —
  /// see docs/ARCHITECTURE.md's Deep Link — Invite Flow.
  String get shareableLink => 'sharedtasks://join/$token';
}
