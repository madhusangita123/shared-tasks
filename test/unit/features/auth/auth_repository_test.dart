// Unit tests for AuthRepositoryImpl — exercises the exception → Result
// mapping in lib/features/auth/data/auth_repository_impl.dart against a
// mocktail-mocked AuthRemoteDatasource. Never touches real Firebase or
// Google Sign-In.
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/auth/data/auth_remote_datasource.dart';
import 'package:shared_tasks/features/auth/data/auth_repository_impl.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';

class MockAuthRemoteDatasource extends Mock implements AuthRemoteDatasource {}

void main() {
  late MockAuthRemoteDatasource mockDatasource;
  late AuthRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockAuthRemoteDatasource();
    repository = AuthRepositoryImpl(datasource: mockDatasource);
  });

  group('signInWithGoogle — success and cancellation', () {
    test('passes through the exact user data from the datasource on success',
        () async {
      const user = AppUser(
        id: 'uid-1',
        displayName: 'Ada Lovelace',
        email: 'ada@example.com',
        photoUrl: 'https://example.com/ada.png',
      );
      when(() => mockDatasource.signInWithGoogle())
          .thenAnswer((_) async => user);

      final result = await repository.signInWithGoogle();

      expect(result, isA<Success<AppUser?>>());
      expect((result as Success<AppUser?>).data, same(user));
    });

    test(
        'maps AuthCancelledException to Success(null) — silent, NOT a '
        'Failure', () async {
      when(() => mockDatasource.signInWithGoogle())
          .thenThrow(const AuthCancelledException());

      final result = await repository.signInWithGoogle();

      expect(result, isA<Success<AppUser?>>());
      expect((result as Success<AppUser?>).data, isNull);
    });
  });

  group('signInWithGoogle — network failures', () {
    test('maps SocketException to Failure(NetworkFailure)', () async {
      when(() => mockDatasource.signInWithGoogle())
          .thenThrow(const SocketException('Failed host lookup'));

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });

    test(
        "maps FirebaseAuthException(code: 'network-request-failed') to "
        'Failure(NetworkFailure)', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error has occurred.',
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });

    test(
        'maps a FirebaseAuthException whose code is unrelated but whose '
        'message mentions connectivity to Failure(NetworkFailure) — proves '
        'the .message field is checked too, not just .code', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        FirebaseAuthException(
          code: 'unknown',
          message: 'Could not reach the server, connection timed out.',
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });

    test(
        // REGRESSION TEST — see lib/features/auth/data/auth_repository_impl.dart
        // for the full story: during manual device testing (WiFi off, real
        // Google account picker) google_sign_in's token exchange
        // (googleUser.authentication) threw a PlatformException — not a
        // SocketException or FirebaseAuthException(code:
        // 'network-request-failed') — and the app incorrectly showed the
        // generic "Sign in failed" message instead of "No internet
        // connection". This pins the fix: a PlatformException whose message
        // clearly indicates a network problem must map to NetworkFailure.
        'REGRESSION: PlatformException from the Google Sign-In token '
        'exchange with network-indicating message text maps to '
        'Failure(NetworkFailure)', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 7: '
              'NetworkError while attempting to fetch resource.',
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });

    test(
        'maps a PlatformException whose network indication is only in its '
        'code (not message) to Failure(NetworkFailure) — proves .code is '
        'checked too, and the match is case-insensitive', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        PlatformException(code: 'NETWORK_ERROR'),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });

    test(
        'maps a generic (non-PlatformException, non-FirebaseAuthException) '
        'exception whose toString() indicates a socket/connectivity problem '
        'to Failure(NetworkFailure) via the catch-all branch', () async {
      // Distinct from the dedicated SocketException test above: a plain
      // Exception whose message merely contains "socket".
      when(() => mockDatasource.signInWithGoogle())
          .thenThrow(Exception('Underlying socket was reset by peer'));

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      expect((result as Failure<AppUser?>).failure, isA<NetworkFailure>());
    });
  });

  group('signInWithGoogle — non-network failures (heuristic must not '
      'over-match)', () {
    test(
        'maps a FirebaseAuthException with an unrelated code to '
        'Failure(AuthFailure) with the generic message', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        FirebaseAuthException(
          code: 'invalid-credential',
          message: 'The supplied auth credential is malformed or expired.',
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      final failure = (result as Failure<AppUser?>).failure;
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'Sign in failed. Try again.');
    });

    test(
        'maps a PlatformException with NO network-related text to '
        'Failure(AuthFailure) with the generic message — proves the '
        'heuristic is not over-broad', () async {
      when(() => mockDatasource.signInWithGoogle()).thenThrow(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 10: '
              'DEVELOPER_ERROR — OAuth client misconfigured.',
        ),
      );

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      final failure = (result as Failure<AppUser?>).failure;
      expect(failure, isA<AuthFailure>());
      expect(failure, isNot(isA<NetworkFailure>()));
      expect((failure as AuthFailure).message, 'Sign in failed. Try again.');
    });

    test(
        'maps a generic exception with no network-related text to '
        'Failure(AuthFailure) with the generic message', () async {
      when(() => mockDatasource.signInWithGoogle())
          .thenThrow(Exception('Something unexpected happened'));

      final result = await repository.signInWithGoogle();

      expect(result, isA<Failure<AppUser?>>());
      final failure = (result as Failure<AppUser?>).failure;
      expect(failure, isA<AuthFailure>());
      expect(failure, isNot(isA<NetworkFailure>()));
      expect((failure as AuthFailure).message, 'Sign in failed. Try again.');
    });
  });

  group('signOut', () {
    test('returns Success(null) when the datasource succeeds', () async {
      when(() => mockDatasource.signOut()).thenAnswer((_) async {});

      final result = await repository.signOut();

      expect(result, isA<Success<void>>());
    });

    test(
        'returns Failure(AuthFailure) with the generic sign-out message when '
        'the datasource throws', () async {
      when(() => mockDatasource.signOut())
          .thenThrow(Exception('sign out boom'));

      final result = await repository.signOut();

      expect(result, isA<Failure<void>>());
      final failure = (result as Failure<void>).failure;
      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).message, 'Sign out failed. Try again.');
    });
  });

  group('authStateChanges', () {
    test("passes through the datasource's stream unchanged", () async {
      const signedIn = AppUser(
        id: 'uid-2',
        displayName: 'Bo',
        email: 'bo@example.com',
      );
      when(() => mockDatasource.authStateChanges)
          .thenAnswer((_) => Stream.fromIterable([signedIn, null]));

      final emissions = await repository.authStateChanges.toList();

      expect(emissions, [signedIn, null]);
    });
  });
}
