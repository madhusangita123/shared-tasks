/// Route path constants — the only place route strings are defined.
///
/// See docs/ARCHITECTURE.md — Navigation (go_router).
abstract final class AppRoutes {
  static const signIn = '/signin';
  static const home = '/home';
  static const settings = '/settings';
  static const createSpace = '/space/create';
  static const taskList = '/space/:spaceId/tasks';
  static const spaceSettings = '/space/:spaceId/settings';
  static const joinSpace = '/join/:token';

  /// [openTaskId] (issue #12) — when supplied, appends `?openTaskId=...`
  /// (URL-encoded) so [TaskListScreen] can auto-open that task's detail
  /// sheet once its data arrives. Used by `notificationTapProvider` to
  /// deep-link a tapped push notification straight to the assigned task,
  /// not just the space's task list.
  static String taskListPath(String spaceId, {String? openTaskId}) {
    final path = '/space/$spaceId/tasks';
    if (openTaskId == null) return path;
    return '$path?openTaskId=${Uri.encodeQueryComponent(openTaskId)}';
  }

  static String spaceSettingsPath(String spaceId) =>
      '/space/$spaceId/settings';

  static String joinSpacePath(String token) => '/join/$token';
}
