import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/features/notifications/presentation/providers/notification_tap_provider.dart';

void main() {
  group('extractTaskDeepLink', () {
    test('returns the (spaceId, taskId) pair when both are present', () {
      final result = extractTaskDeepLink({
        'spaceId': 'space-1',
        'taskId': 'task-1',
      });

      expect(result, isNotNull);
      expect(result!.spaceId, 'space-1');
      expect(result.taskId, 'task-1');
    });

    test('returns null when spaceId is missing', () {
      final result = extractTaskDeepLink({'taskId': 'task-1'});

      expect(result, isNull);
    });

    test('returns null when taskId is missing', () {
      final result = extractTaskDeepLink({'spaceId': 'space-1'});

      expect(result, isNull);
    });

    test('returns null when spaceId is an empty string', () {
      final result = extractTaskDeepLink({
        'spaceId': '',
        'taskId': 'task-1',
      });

      expect(result, isNull);
    });

    test('returns null when taskId is an empty string', () {
      final result = extractTaskDeepLink({
        'spaceId': 'space-1',
        'taskId': '',
      });

      expect(result, isNull);
    });
  });
}
