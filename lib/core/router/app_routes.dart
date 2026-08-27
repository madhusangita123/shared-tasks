/// Route path constants — the only place route strings are defined.
///
/// See docs/ARCHITECTURE.md — Navigation (go_router).
abstract final class AppRoutes {
  static const signIn = '/signin';
  static const home = '/home';
  static const createSpace = '/space/create';
  static const taskList = '/space/:spaceId/tasks';
  static const spaceSettings = '/space/:spaceId/settings';
  static const joinSpace = '/join/:token';

  static String taskListPath(String spaceId) => '/space/$spaceId/tasks';

  static String spaceSettingsPath(String spaceId) =>
      '/space/$spaceId/settings';

  static String joinSpacePath(String token) => '/join/$token';
}
