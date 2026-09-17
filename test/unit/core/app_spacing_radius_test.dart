import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/theme/app_radius.dart';
import 'package:shared_tasks/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('has the exact expected numeric scale', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });
  });

  group('AppRadius', () {
    test('has the exact expected numeric scale', () {
      expect(AppRadius.radiusSm, 8);
      expect(AppRadius.radiusMd, 12);
      expect(AppRadius.radiusLg, 16);
      expect(AppRadius.radiusFull, 99);
    });
  });
}
