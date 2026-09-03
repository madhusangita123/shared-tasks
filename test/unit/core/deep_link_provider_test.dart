import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/router/deep_link_provider.dart';

void main() {
  group('extractJoinToken', () {
    test('returns the token for a valid sharedtasks://join/{token} uri', () {
      final uri = Uri.parse('sharedtasks://join/abc123');

      expect(extractJoinToken(uri), 'abc123');
    });

    test('returns null when the host is not join', () {
      final uri = Uri.parse('sharedtasks://somethingelse/abc123');

      expect(extractJoinToken(uri), isNull);
    });

    test('returns null when host is join but there are no path segments',
        () {
      final uri = Uri.parse('sharedtasks://join');

      expect(extractJoinToken(uri), isNull);
    });
  });
}
