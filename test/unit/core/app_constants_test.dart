import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/constants/app_constants.dart';

void main() {
  group('AppConstants', () {
    test('space name length bounds match the PRD', () {
      expect(AppConstants.spaceNameMinLength, 3);
      expect(AppConstants.spaceNameMaxLength, 40);
    });

    test('task field limits match the PRD', () {
      expect(AppConstants.taskTitleMaxLength, 120);
      expect(AppConstants.taskNotesMaxLength, 500);
    });

    test('invite link validity is 1 year', () {
      expect(AppConstants.inviteLinkValidity, const Duration(days: 365));
    });

    test('undo snackbar duration matches the delete acceptance criteria', () {
      expect(AppConstants.undoSnackbarDuration, const Duration(seconds: 5));
    });

    test('non-functional requirement targets match the PRD', () {
      expect(AppConstants.syncLatencyTarget, const Duration(seconds: 2));
      expect(AppConstants.coldStartTarget, const Duration(seconds: 2));
      expect(
        AppConstants.pushNotificationDelayTarget,
        const Duration(seconds: 30),
      );
    });
  });
}
