import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/extensions/datetime_extensions.dart';

void main() {
  group('DateTimeExtensions', () {
    test('isToday is true for now', () {
      expect(DateTime.now().isToday, isTrue);
    });

    test('isToday is false for a different day', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(yesterday.isToday, isFalse);
    });

    test('isPast / isFuture', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 1));
      expect(past.isPast, isTrue);
      expect(future.isFuture, isTrue);
    });

    test('isPast is false for a future date, isFuture is false for a past date', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final future = DateTime.now().add(const Duration(days: 1));
      expect(future.isPast, isFalse);
      expect(past.isFuture, isFalse);
    });

    test('toRelativeTime returns "just now" for the current moment', () {
      expect(DateTime.now().toRelativeTime(), 'just now');
    });

    test('toRelativeTime returns minutes ago under an hour', () {
      final time = DateTime.now().subtract(const Duration(minutes: 5));
      expect(time.toRelativeTime(), '5m ago');
    });

    test('toRelativeTime returns hours ago under a day', () {
      final time = DateTime.now().subtract(const Duration(hours: 3));
      expect(time.toRelativeTime(), '3h ago');
    });

    test('toRelativeTime returns days ago under a week', () {
      final time = DateTime.now().subtract(const Duration(days: 2));
      expect(time.toRelativeTime(), '2d ago');
    });

    test('toRelativeTime falls back to a calendar date after a week', () {
      final oldEnough = DateTime.now().subtract(const Duration(days: 10));
      expect(
        oldEnough.toRelativeTime(),
        '${oldEnough.day}/${oldEnough.month}/${oldEnough.year}',
      );
    });
  });
}
