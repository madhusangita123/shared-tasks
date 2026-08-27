import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('status colors are distinct', () {
      expect(
        {
          AppColors.statusTodo,
          AppColors.statusInProgress,
          AppColors.statusDone,
        },
        hasLength(3),
      );
    });

    test('error and success colors are distinct', () {
      expect(AppColors.error, isNot(AppColors.success));
    });

    test('brand colors are distinct', () {
      expect(
        {AppColors.primary, AppColors.primaryDark, AppColors.secondary},
        hasLength(3),
      );
    });

    test('background and surface are distinct', () {
      expect(AppColors.background, isNot(AppColors.surface));
    });
  });
}
