import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_tasks/core/errors/failure.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/auth/data/auth_remote_datasource.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/domain/repositories/auth_repository.dart';

/// Firebase-backed [AuthRepository]. Never throws — every failure from
/// [AuthRemoteDatasource] is caught here and mapped to a [Result].
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required AuthRemoteDatasource datasource})
    : _datasource = datasource;

  final AuthRemoteDatasource _datasource;

  @override
  Future<Result<AppUser?>> signInWithGoogle() async {
    try {
      final user = await _datasource.signInWithGoogle();
      return Success(user);
    } on AuthCancelledException {
      // User dismissed the picker — silent, not an error.
      return const Success(null);
    } on SocketException {
      return const Failure(NetworkFailure());
    } on FirebaseAuthException catch (e) {
      if (_isNetworkRelated(e.code) || _isNetworkRelated(e.message)) {
        return const Failure(NetworkFailure());
      }
      return const Failure(AuthFailure('Sign in failed. Try again.'));
    } on PlatformException catch (e) {
      // google_sign_in's token exchange (googleUser.authentication) needs
      // network and throws a PlatformException on failure — not a
      // SocketException or FirebaseAuthException — so it needs its own
      // check here. The exact code/message varies by platform and plugin
      // version, hence the substring heuristic in _isNetworkRelated rather
      // than matching one exact code.
      if (_isNetworkRelated(e.code) || _isNetworkRelated(e.message)) {
        return const Failure(NetworkFailure());
      }
      return const Failure(AuthFailure('Sign in failed. Try again.'));
    } catch (e) {
      // Last-resort net: any other exception type whose text still clearly
      // indicates a connectivity problem should surface as NetworkFailure
      // rather than the generic message.
      if (_isNetworkRelated(e.toString())) {
        return const Failure(NetworkFailure());
      }
      return const Failure(AuthFailure('Sign in failed. Try again.'));
    }
  }

  /// Loose, case-insensitive substring match for connectivity-related
  /// error text. Deliberately broad: native Firebase Auth / Google
  /// Sign-In SDKs report network failures with inconsistent exception
  /// types and codes across Android/iOS and plugin versions, so matching
  /// exact codes alone (e.g. only `network-request-failed`) misses real
  /// cases — this was the root cause of a confirmed bug where a real
  /// offline sign-in attempt showed "Sign in failed" instead of the
  /// required "No internet connection" message.
  static bool _isNetworkRelated(String? text) {
    if (text == null) return false;
    final lower = text.toLowerCase();
    return lower.contains('network') ||
        lower.contains('internet') ||
        lower.contains('unreachable') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('failed to connect') ||
        lower.contains('socket');
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Success(null);
    } catch (_) {
      return const Failure(AuthFailure('Sign out failed. Try again.'));
    }
  }

  @override
  Stream<AppUser?> get authStateChanges => _datasource.authStateChanges;
}
