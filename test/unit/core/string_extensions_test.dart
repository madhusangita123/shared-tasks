import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions', () {
    test('isBlank / isNotBlank', () {
      expect('   '.isBlank, isTrue);
      expect('hi'.isBlank, isFalse);
      expect('hi'.isNotBlank, isTrue);
    });

    test('capitalize uppercases first letter only', () {
      expect('hello'.capitalize(), 'Hello');
      expect(''.capitalize(), '');
    });

    test('truncate shortens long strings with an ellipsis', () {
      expect('hello world'.truncate(5), 'hello…');
      expect('hi'.truncate(5), 'hi');
    });
  });

  group('NullableStringExtensions', () {
    test('isNullOrBlank', () {
      const String? nullString = null;
      expect(nullString.isNullOrBlank, isTrue);
      expect('  '.isNullOrBlank, isTrue);
      expect('hi'.isNullOrBlank, isFalse);
    });
  });
}
