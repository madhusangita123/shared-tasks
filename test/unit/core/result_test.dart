import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Success wraps data', () {
      const result = Success<int>(1);
      expect(result.data, 1);
    });

    test('Failure wraps an AppFailure', () {
      const result = Failure<int>(UnknownFailure());
      expect(result.failure, isA<UnknownFailure>());
    });

    test('exhaustive switch handles the success case', () {
      const Result<int> result = Success<int>(1);
      final value = switch (result) {
        Success(:final data) => data,
        Failure() => -1,
      };
      expect(value, 1);
    });

    test('exhaustive switch handles the failure case', () {
      const Result<int> result = Failure<int>(NetworkFailure());
      final value = switch (result) {
        Success(:final data) => data,
        Failure(:final failure) => failure.message,
      };
      expect(value, 'No internet connection');
    });
  });
}
