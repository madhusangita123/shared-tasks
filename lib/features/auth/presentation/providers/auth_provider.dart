import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_tasks/core/errors/result.dart';
import 'package:shared_tasks/features/auth/data/auth_remote_datasource.dart';
import 'package:shared_tasks/features/auth/data/auth_repository_impl.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';
import 'package:shared_tasks/features/auth/domain/repositories/auth_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    datasource: AuthRemoteDatasource(
      firebaseAuth: ref.watch(firebaseAuthProvider),
      googleSignIn: ref.watch(googleSignInProvider),
    ),
  );
});

/// Emits the signed-in [AppUser], or `null` when signed out. Drives the
/// router redirect and "returning user lands on home" behavior.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Drives the "Continue with Google" button on the sign-in screen.
///
/// A cancelled picker resolves to a neutral [AsyncData] state — never
/// [AsyncError] — so the screen shows no error.
class SignInNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signInWithGoogle();
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(
        failure,
        StackTrace.current,
      ),
    };
  }
}

final signInProvider = AsyncNotifierProvider<SignInNotifier, void>(
  SignInNotifier.new,
);

/// Signs the user out of both Firebase Auth and Google Sign-In.
class SignOutNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signOut();
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError<void>(
        failure,
        StackTrace.current,
      ),
    };
  }
}

final signOutProvider = AsyncNotifierProvider<SignOutNotifier, void>(
  SignOutNotifier.new,
);
