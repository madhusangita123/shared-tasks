/// App-wide limits, timeouts, and other non-Firestore constants.
///
/// Values sourced from the PRD's acceptance criteria and non-functional
/// requirements — see docs/SharedTasks_MVP1_PRD.md.
abstract final class AppConstants {
  // Space (US-03)
  static const spaceNameMinLength = 3;
  static const spaceNameMaxLength = 40;

  // Tasks (US-05)
  static const taskTitleMaxLength = 120;
  static const taskNotesMaxLength = 500;
  static const undoSnackbarDuration = Duration(seconds: 5);

  // Invite links (US-04)
  static const inviteLinkValidity = Duration(days: 365);

  /// Base URL of the Firebase Hosting landing page invite links point at
  /// (issue #37) — a real `https://` URL so chat apps render it as a
  /// tappable link, unlike the raw `sharedtasks://` scheme it hands off to.
  /// See `hosting/join/index.html` and `docs/ARCHITECTURE.md`.
  ///
  /// Hardcoded to the dev project: there's no build-flavor/environment
  /// split in the app yet, and `shared-tasks-prod` (issue #19) isn't fully
  /// configured yet either. Once both exist, this needs to become
  /// environment-aware rather than a single constant.
  static const inviteLandingPageBaseUrl = 'https://shared-tasks-dev.web.app';

  // Non-functional requirements
  static const syncLatencyTarget = Duration(seconds: 2);
  static const coldStartTarget = Duration(seconds: 2);
  static const pushNotificationDelayTarget = Duration(seconds: 30);
}
