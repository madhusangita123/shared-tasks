import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/router/app_routes.dart';

void main() {
  group('AppRoutes', () {
    test('static route constants match the documented paths', () {
      expect(AppRoutes.signIn, '/signin');
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.createSpace, '/space/create');
      expect(AppRoutes.taskList, '/space/:spaceId/tasks');
      expect(AppRoutes.spaceSettings, '/space/:spaceId/settings');
      expect(AppRoutes.joinSpace, '/join/:token');
    });

    test('taskListPath builds the concrete path for a space', () {
      expect(AppRoutes.taskListPath('abc123'), '/space/abc123/tasks');
    });

    test('spaceSettingsPath builds the concrete path for a space', () {
      expect(AppRoutes.spaceSettingsPath('abc123'), '/space/abc123/settings');
    });

    test('joinSpacePath builds the concrete path for a token', () {
      expect(AppRoutes.joinSpacePath('tok123'), '/join/tok123');
    });
  });
}
