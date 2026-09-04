// Unit tests for the Invite entity's shareableLink getter (issue #37).
// Pure Dart, no mocking needed — just verifies the URL it builds.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';
import 'package:shared_tasks/features/invite/domain/entities/invite.dart';

void main() {
  group('Invite.shareableLink', () {
    test('builds an https:// URL under the landing page base URL, with '
        'the token as the last path segment', () {
      final invite = Invite(
        spaceId: 'space-1',
        token: 'tok-abc-123',
        expiresAt: DateTime(2027, 1, 1),
      );

      expect(
        invite.shareableLink,
        '${AppConstants.inviteLandingPageBaseUrl}/join/tok-abc-123',
      );
    });

    test('is a real https:// URL, not the raw sharedtasks:// scheme', () {
      final invite = Invite(
        spaceId: 'space-1',
        token: 'tok-xyz',
        expiresAt: DateTime(2027, 1, 1),
      );

      expect(invite.shareableLink, startsWith('https://'));
      expect(invite.shareableLink, isNot(contains('sharedtasks://')));
    });

    test('reflects the exact token passed in, not a previous one', () {
      final first = Invite(
        spaceId: 'space-1',
        token: 'tok-first',
        expiresAt: DateTime(2027, 1, 1),
      );
      final second = Invite(
        spaceId: 'space-1',
        token: 'tok-second',
        expiresAt: DateTime(2027, 1, 1),
      );

      expect(first.shareableLink, endsWith('/join/tok-first'));
      expect(second.shareableLink, endsWith('/join/tok-second'));
    });
  });
}
