import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';

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

  /// The link recipients tap to join — a real `https://` URL (issue #37)
  /// so WhatsApp/iMessage/SMS render it as a tappable link, unlike the raw
  /// `sharedtasks://join/{token}` scheme it hands off to once opened. See
  /// `hosting/join/index.html` and docs/ARCHITECTURE.md's Deep Link —
  /// Invite Flow.
  String get shareableLink =>
      '${AppConstants.inviteLandingPageBaseUrl}/join/$token';
}
