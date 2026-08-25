# SharedTasks — Architecture Document
**Version:** 2.0  
**Status:** Approved  
**Date:** August 2026

---

## Overview

SharedTasks follows a **feature-first Clean Architecture**. Each feature is self-contained with its own data, domain, and presentation layers. Shared infrastructure lives in `core/`. This keeps feature work co-located and makes the codebase easy to navigate for both humans and Claude Code.

---

## Folder Structure

```
lib/
├── main.dart                        ← entry point, Firebase init, ProviderScope
├── app.dart                         ← MaterialApp.router, theme, go_router setup
│
├── core/                            ← shared across all features
│   ├── errors/
│   │   ├── failure.dart             ← sealed AppFailure types
│   │   └── result.dart              ← Result<T> sealed class
│   ├── extensions/
│   │   ├── string_extensions.dart
│   │   └── datetime_extensions.dart
│   ├── constants/
│   │   ├── firestore_constants.dart ← collection/field name strings
│   │   └── app_constants.dart       ← timeouts, limits, etc.
│   ├── theme/
│   │   ├── app_theme.dart           ← MaterialTheme, colors, typography
│   │   └── app_colors.dart
│   ├── router/
│   │   ├── app_router.dart          ← go_router config, all routes
│   │   └── app_routes.dart          ← route name constants
│   └── widgets/                     ← truly shared widgets
│       ├── app_button.dart
│       ├── app_text_field.dart
│       └── loading_overlay.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_remote_datasource.dart     ← Google sign-in + Firebase Auth
│   │   │   └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── app_user.dart               ← freezed, no Firebase deps
│   │   │   └── repositories/
│   │   │       └── auth_repository.dart        ← abstract interface
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart          ← manual Riverpod providers
│   │       └── sign_in_screen.dart             ← Google sign-in only
│   │
│   ├── home/
│   │   ├── data/
│   │   │   ├── home_remote_datasource.dart     ← query spaces by memberUids
│   │   │   └── home_repository_impl.dart
│   │   ├── domain/
│   │   │   └── repositories/
│   │   │       └── home_repository.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── home_provider.dart          ← StreamProvider for all user spaces
│   │       └── home_screen.dart               ← all spaces list
│   │
│   ├── spaces/
│   │   ├── data/
│   │   │   ├── spaces_remote_datasource.dart   ← Firestore CRUD for spaces
│   │   │   └── spaces_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── space.dart                  ← freezed
│   │   │   └── repositories/
│   │   │       └── spaces_repository.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── spaces_provider.dart
│   │       ├── create_space_screen.dart
│   │       └── space_settings_screen.dart      ← members list, share button
│   │
│   ├── invite/
│   │   ├── data/
│   │   │   ├── invite_remote_datasource.dart   ← token generation, join space
│   │   │   └── invite_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── invite.dart                 ← freezed
│   │   │   └── repositories/
│   │   │       └── invite_repository.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── invite_provider.dart
│   │       └── invite_screen.dart              ← share link UI in space settings
│   │
│   └── tasks/
│       ├── data/
│       │   ├── tasks_remote_datasource.dart    ← Firestore realtime listeners
│       │   └── tasks_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── task.dart                   ← freezed
│       │   │   └── task_status.dart            ← enum: todo, in_progress, done
│       │   └── repositories/
│       │       └── tasks_repository.dart
│       └── presentation/
│           ├── providers/
│           │   └── tasks_provider.dart
│           ├── task_list_screen.dart
│           └── task_detail_sheet.dart          ← bottom sheet, not a screen
│
test/
├── unit/
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── spaces/
│   │   ├── invite/
│   │   └── tasks/
│   └── core/
└── widget/
    └── features/
        ├── auth/
        ├── home/
        ├── spaces/
        └── tasks/
```

---

## Core Patterns

### Result Type

All repository methods return `Result<T>` — never throw, never return null for errors.

```dart
// core/errors/result.dart
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}
```

```dart
// core/errors/failure.dart
sealed class AppFailure {
  const AppFailure(this.message);
  final String message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure() : super('No internet connection');
}

final class AuthFailure extends AppFailure {
  const AuthFailure(String message) : super(message);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(String message) : super(message);
}

final class PermissionFailure extends AppFailure {
  const PermissionFailure() : super('You do not have permission');
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure() : super('Something went wrong');
}
```

**Usage in repository:**
```dart
Future<Result<Task>> addTask(Task task) async {
  try {
    await _datasource.addTask(task);
    return Success(task);
  } on FirebaseException catch (e) {
    return Failure(UnknownFailure());
  }
}
```

**Usage in provider:**
```dart
final result = await ref.read(tasksRepositoryProvider).addTask(task);
switch (result) {
  case Success(:final data):
    // update state
  case Failure(:final failure):
    // show error
}
```

---

### Riverpod Manual Providers

Three provider types used in this project:

**1. Infrastructure providers** — Firebase instances, datasources, repositories

```dart
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
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
```

**2. AsyncNotifierProvider** — for mutable state with async operations

```dart
class SignInNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithGoogle();
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final failure) => AsyncError(failure, StackTrace.current),
    };
  }
}

final signInProvider = AsyncNotifierProvider<SignInNotifier, void>(
  SignInNotifier.new,
);
```

**3. StreamProvider** — for Firestore realtime listeners

```dart
// Watch all spaces for the current user
final userSpacesProvider = StreamProvider.autoDispose<List<Space>>((ref) {
  final uid = ref.watch(currentUserProvider).valueOrNull?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(homeRepositoryProvider).watchUserSpaces(uid);
});

// Watch tasks for a specific space
final taskListProvider = StreamProvider.autoDispose.family<List<Task>, String>((ref, spaceId) {
  return ref.watch(tasksRepositoryProvider).watchTasks(spaceId);
});
```

---

### Domain Entities (freezed)

```dart
// features/auth/domain/entities/app_user.dart
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String displayName,
    required String email,
    String? photoUrl,
    String? fcmToken,
  }) = _AppUser;
}

// features/spaces/domain/entities/space.dart
@freezed
class Space with _$Space {
  const factory Space({
    required String id,
    required String name,
    required String ownerUid,
    required List<String> memberUids,
    required String inviteToken,
    required DateTime inviteExpiresAt,
    required DateTime createdAt,
  }) = _Space;

  factory Space.fromJson(Map<String, dynamic> json) => _$SpaceFromJson(json);
}

// features/tasks/domain/entities/task.dart
@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String spaceId,
    required String title,
    String? notes,
    required TaskStatus status,
    String? assigneeUid,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
```

---

## Navigation (go_router)

```dart
// core/router/app_router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: AppRoutes.signIn,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isOnAuth = state.matchedLocation == AppRoutes.signIn;
      if (!isAuthenticated && !isOnAuth) return AppRoutes.signIn;
      if (isAuthenticated && isOnAuth) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.createSpace,
        builder: (_, __) => const CreateSpaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskList,
        builder: (_, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return TaskListScreen(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.spaceSettings,
        builder: (_, state) {
          final spaceId = state.pathParameters['spaceId']!;
          return SpaceSettingsScreen(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: AppRoutes.joinSpace,
        builder: (_, state) {
          final token = state.pathParameters['token']!;
          return JoinSpaceScreen(token: token);
        },
      ),
    ],
  );
});

// core/router/app_routes.dart
abstract final class AppRoutes {
  static const signIn       = '/signin';
  static const home         = '/home';
  static const createSpace  = '/space/create';
  static const taskList     = '/space/:spaceId/tasks';
  static const spaceSettings = '/space/:spaceId/settings';
  static const joinSpace    = '/join/:token';
}
```

---

## Auth — Google Sign-In Flow

```dart
// features/auth/data/datasources/auth_remote_datasource.dart
class AuthRemoteDatasource {
  const AuthRemoteDatasource({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw const AuthCancelledException();

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Upsert user doc in Firestore
    await _upsertUserDoc(user);

    return AppUser(
      id: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
    );
  }

  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
```

---

## Deep Link — Invite Flow

We use the **`app_links`** Flutter package for deep linking. No custom domain, no server hosting, no SHA256 fingerprints needed for MVP 1.

### Package

```yaml
dependencies:
  app_links: ^6.0.0
```

### How it works

```
Owner taps "Share" in space settings
  → App generates invite token (stored in Firestore, expires 1 year)
  → Builds link: sharedtasks://join/{token}
  → Opens native share sheet

Recipient taps link
  ├── App installed → OS intercepts via app_links → opens JoinSpaceScreen(token)
  │     → validates token → adds uid to space.memberUids
  │     → navigates to home screen (space now appears there)
  └── App not installed → link fails to open
        → Recipient installs app manually from App Store/Play Store
        → Owner resends link or recipient enters token manually
        → MVP 2: proper deferred deep linking

After install:
  → User signs in with Google
  → App listens for incoming links via app_links
  → If valid token found → joins space → lands on home screen
```

### Android setup — `AndroidManifest.xml`

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="sharedtasks" android:host="join" />
</intent-filter>
```

### iOS setup — `Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sharedtasks</string>
    </array>
  </dict>
</array>
```

### Flutter — listening for links

```dart
// In main.dart or app.dart
final appLinks = AppLinks();

appLinks.uriLinkStream.listen((uri) {
  if (uri.host == 'join') {
    final token = uri.pathSegments.first;
    // navigate to JoinSpaceScreen(token)
  }
});
```

### Key decisions
- Link format: `sharedtasks://join/{token}` — custom URI scheme, no domain needed
- Valid for **1 year**, **multi-use**
- **No accept screen** — space appears in home screen automatically on join
- Link invalidated only when owner regenerates it
- ⚠️ Deferred deep linking (app not installed flow) — MVP 2

---

## ADR update

**ADR-004 revised** — `app_links` custom URI scheme over App Links + Universal Links  
*Reason:* App Links and Universal Links require a custom domain, hosted `/.well-known/` files, SHA256 cert fingerprints, and Apple team ID setup — too much infrastructure for MVP 1. `app_links` with a custom URI scheme (`sharedtasks://`) works on both platforms with just a manifest entry. Deferred deep linking (app not installed) is acceptable as a known limitation for MVP 1.

---

## Firebase Setup

### Collections

```
users/                           ← one doc per authenticated user
spaces/                          ← one doc per space (private or shared)
spaces/{spaceId}/tasks/          ← subcollection, all tasks for a space
```

### Key query pattern

Users no longer have a `spaceId` field. To get all spaces for a user:

```dart
// Query spaces where current user is a member
FirebaseFirestore.instance
  .collection('spaces')
  .where('memberUids', arrayContains: currentUid)
  .snapshots();
```

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users — read/write own doc only
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    // Spaces — members can read/write, owner can delete
    match /spaces/{spaceId} {
      allow read: if request.auth.uid in resource.data.memberUids;
      allow create: if request.auth.uid == request.resource.data.ownerUid
                    && request.auth.uid in request.resource.data.memberUids;
      allow update: if request.auth.uid in resource.data.memberUids;
      allow delete: if request.auth.uid == resource.data.ownerUid;

      // Tasks — space members only
      match /tasks/{taskId} {
        allow read, write: if request.auth.uid in
          get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberUids;
      }
    }

    // Join via invite token — handled server-side via Cloud Function
    // Token validation keeps invite logic off the client
  }
}
```

---

## Firebase Environments

| Environment | Firebase Project | Used for |
|---|---|---|
| dev | shared-tasks-dev | Day to day development |
| test | Firebase Emulator Suite | Unit + widget tests |
| prod | shared-tasks-prod | Live app (MVP 1 launch) |

### Emulator config (test)

```dart
// test/helpers/firebase_test_helper.dart
Future<void> setupFirebaseEmulators() async {
  await Firebase.initializeApp();
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

### Running emulators

```bash
firebase emulators:start --only firestore,auth,functions
```

---

## pubspec.yaml — Key Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  go_router: ^13.2.0
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_messaging: ^15.0.0
  google_sign_in: ^6.2.1
  app_links: ^6.0.0
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  build_runner: ^2.4.9
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.3
```

---

## Code Generation

Run after adding or changing any freezed model:

```bash
dart run build_runner build --delete-conflicting-outputs
```

For continuous watch during development:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

---

## Testing Strategy

| Test type | Location | Runs against | What it covers |
|---|---|---|---|
| Unit | `test/unit/` | Emulator / mocks | Repositories, entities, Result handling |
| Widget | `test/widget/` | Mocks | Screens, providers, UI interactions |
| Integration | (MVP 2) | Emulator | Full user flows end to end |

---

## Conventions

| Thing | Convention |
|---|---|
| Files | `snake_case.dart` |
| Classes | `PascalCase` |
| Providers | `camelCaseProvider` |
| Routes | defined in `AppRoutes` constants only |
| Firestore field names | `camelCase` strings in `FirestoreConstants` — never hardcoded |
| Commit messages | Conventional commits: `feat:` `fix:` `chore:` `test:` `docs:` |
| Branch names | `feat/us-XX-short-description` |

---

## Feature Build Order (MVP 1)

Build strictly in this sequence — each feature depends on the previous:

1. `core/` — Result type, failures, theme, router, shared widgets
2. `auth/` — Google sign-in, persistent session, user doc upsert
3. `home/` — all spaces list, StreamProvider querying by memberUids
4. `spaces/` — create space, space settings screen
5. `invite/` — generate link, join space via token, deep link handling
6. `tasks/` — task list, add, edit, delete, assign, status, live sync
7. `functions/` — push notifications on assignment via Cloud Functions

---

## ADR Log

**ADR-001** — Feature-first over layer-first  
*Reason:* Co-location of feature code improves Claude Code agent effectiveness and developer navigation. Layers still exist within each feature.

**ADR-002** — Manual Riverpod providers over code gen  
*Reason:* Eliminates build_runner step from the agentic workflow loop. Explicit providers are easier to read and debug.

**ADR-003** — Custom Result<T> sealed class over fpdart Either  
*Reason:* No third-party dependency. Dart 3 sealed classes + pattern matching give the same exhaustive handling with zero extra packages.

**ADR-004** — App Links + Universal Links over Branch.io  
*Reason:* No cost, no third-party SDK. Firebase Dynamic Links shut down Aug 2025. Custom domain + Cloud Function serves verification files.

**ADR-005** — Firebase Emulator for tests, real project for dev  
*Reason:* Keeps test suite fast, isolated and free. Real project used for dev gives realistic Firestore behaviour during feature development.

**ADR-006** — Google sign-in only, no email/password  
*Reason:* Zero friction — one tap, no account creation, no password to remember. Display name and avatar come from Google automatically. Fits the household use case where both users have Google accounts.

**ADR-007** — Multiple spaces per user, per-space sharing  
*Reason:* Users need both private lists (personal todos) and shared lists (house chores, kids activities). Different lists can be shared with different people. One shared space was too limiting for real household use.

**ADR-008** — Invite link valid 1 year, multi-use, no accept screen  
*Reason:* 48-hour single-use links were too restrictive for household sharing. Link sent via WhatsApp may be tapped days later. Multiple people joining via same link is a valid use case. No accept screen reduces friction — space just appears in home screen.

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | April 2026 | Initial architecture — single space, email/password auth |
| 2.0 | August 2026 | Google sign-in only. Multiple spaces per user. Home feature added. Invite link 1 year multi-use. Firestore query pattern updated. New ADRs 006-008. |