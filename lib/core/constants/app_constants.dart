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

  // Non-functional requirements
  static const syncLatencyTarget = Duration(seconds: 2);
  static const coldStartTarget = Duration(seconds: 2);
  static const pushNotificationDelayTarget = Duration(seconds: 30);
}
