import 'package:flutter_test/flutter_test.dart';
import 'package:shared_tasks/core/errors/failure.dart';

void main() {
  group('AppFailure', () {
    test('NetworkFailure has default message', () {
      expect(const NetworkFailure().message, 'No internet connection');
    });

    test('AuthFailure carries a custom message', () {
      expect(const AuthFailure('bad credentials').message, 'bad credentials');
    });

    test('NotFoundFailure carries a custom message', () {
      expect(const NotFoundFailure('task not found').message, 'task not found');
    });

    test('PermissionFailure has default message', () {
      expect(const PermissionFailure().message, 'You do not have permission');
    });

    test('UnknownFailure has default message', () {
      expect(const UnknownFailure().message, 'Something went wrong');
    });
  });
}
