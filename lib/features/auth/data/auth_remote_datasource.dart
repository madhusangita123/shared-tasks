import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_tasks/core/constants/firestore_constants.dart';
import 'package:shared_tasks/features/auth/domain/entities/app_user.dart';

/// Thrown when the user dismisses the native Google account picker without
/// choosing an account. Distinguishable from a real error so the repository
/// layer can treat it as a silent no-op instead of a [Failure].
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// All Firebase Auth, Google Sign-In, and Firestore user-doc calls for the
/// auth feature live here — nothing above this layer touches Firebase or
/// Google Sign-In directly.
class AuthRemoteDatasource {
  AuthRemoteDatasource({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  /// Triggers the native Google account picker, signs in to Firebase Auth
  /// with the resulting credential, and upserts the `users/{uid}` doc.
  ///
  /// Throws [AuthCancelledException] if the user dismisses the picker.
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const AuthCancelledException();

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(
      credential,
    );
    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'Firebase returned no user after sign-in.',
      );
    }

    final appUser = AppUser(
      id: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );

    await _upsertUserDoc(appUser);

    return appUser;
  }

  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  /// Emits the signed-in [AppUser], or `null` when signed out.
  ///
  /// For existing sessions on app restart this reads cached Firebase user
  /// fields (`displayName`/`email`/`photoURL` off `FirebaseAuth.currentUser`)
  /// rather than re-fetching the Firestore doc, keeping restore instant and
  /// offline-safe.
  Stream<AppUser?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) return null;
      return AppUser(
        id: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );
    });
  }

  Future<void> _upsertUserDoc(AppUser user) {
    return _firestore
        .collection(FirestoreConstants.usersCollection)
        .doc(user.id)
        .set(
          {
            FirestoreConstants.displayName: user.displayName,
            FirestoreConstants.email: user.email,
            FirestoreConstants.photoUrl: user.photoUrl,
            FirestoreConstants.createdAt: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }
}
