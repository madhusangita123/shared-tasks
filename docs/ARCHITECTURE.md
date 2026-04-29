# SharedTasks — Architecture Document
**Version:** 1.0  
**Status:** Approved  
**Date:** April 2026

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
│   │   ├── failure.dart             ← sealed Failure class
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
│   │   │   ├── auth_remote_datasource.dart     ← Firebase Auth calls
│   │   │   └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── app_user.dart               ← freezed, no Firebase deps
│   │   │   └── repositories/
│   │   │       └── auth_repository.dart        ← abstract interface
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── auth_provider.dart          ← manual Riverpod providers
│   │       ├── sign_in_screen.dart
│   │       └── sign_up_screen.dart
│   │
│   ├── spaces/
│   │   ├── data/
│   │   │   ├── spaces_remote_datasource.dart   ← Firestore calls
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
│   │       └── space_settings_screen.dart
│   │
│   ├── invite/
│   │   ├── data/
│   │   │   ├── invite_remote_datasource.dart   ← Firestore + link generation
│   │   │   └── invite_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── invite.dart                 ← freezed
│   │   │   └── repositories/
│   │   │       └── invite_repository.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── invite_provider.dart
│   │       ├── invite_screen.dart              ← share link UI
│   │       └── accept_invite_screen.dart       ← deep link landing
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
│   │   ├── spaces/
│   │   ├── invite/
│   │   └── tasks/
│   └── core/
└── widget/
    └── features/
        ├── auth/
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
// Never rebuild, created once
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    datasource: AuthRemoteDatasource(ref.watch(firebaseAuthProvider)),
  );
});
```

**2. AsyncNotifierProvider** — for mutable state with async operations (sign in, add task)

```dart
class SignInNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email, password);
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
final taskListProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final spaceId = ref.watch(currentSpaceIdProvider);
  return ref.watch(tasksRepositoryProvider).watchTasks(spaceId);
});
```

---

### Domain Entities (freezed)

```dart
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

### Repository Interface (domain)

```dart
// features/tasks/domain/repositories/tasks_repository.dart
abstract interface class TasksRepository {
  Stream<List<Task>> watchTasks(String spaceId);
  Future<Result<Task>> addTask({required String spaceId, required String title, String? notes});
  Future<Result<Task>> updateTask(Task task);
  Future<Result<void>> deleteTask({required String spaceId, required String taskId});
  Future<Result<void>> assignTask({required String spaceId, required String taskId, String? assigneeUid});
  Future<Result<void>> updateStatus({required String spaceId, required String taskId, required TaskStatus status});
}
```

---

### Repository Implementation (data)

```dart
// features/tasks/data/tasks_repository_impl.dart
class TasksRepositoryImpl implements TasksRepository {
  const TasksRepositoryImpl({required TasksRemoteDatasource datasource});
  final TasksRemoteDatasource _datasource;

  @override
  Stream<List<Task>> watchTasks(String spaceId) {
    return _datasource.watchTasks(spaceId);
  }

  @override
  Future<Result<Task>> addTask({required String spaceId, required String title, String? notes}) async {
    try {
      final task = await _datasource.addTask(spaceId: spaceId, title: title, notes: notes);
      return Success(task);
    } on FirebaseException catch (e) {
      return Failure(UnknownFailure());
    }
  }
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
      final isOnAuth = state.matchedLocation == AppRoutes.signIn ||
                       state.matchedLocation == AppRoutes.signUp;
      if (!isAuthenticated && !isOnAuth) return AppRoutes.signIn;
      if (isAuthenticated && isOnAuth) return AppRoutes.tasks;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: AppRoutes.createSpace, builder: (_, __) => const CreateSpaceScreen()),
      GoRoute(path: AppRoutes.invite, builder: (_, __) => const InviteScreen()),
      GoRoute(path: AppRoutes.acceptInvite, builder: (_, state) {
        final token = state.pathParameters['token']!;
        return AcceptInviteScreen(token: token);
      }),
      GoRoute(path: AppRoutes.tasks, builder: (_, __) => const TaskListScreen()),
    ],
  );
});

// core/router/app_routes.dart
abstract final class AppRoutes {
  static const signUp       = '/signup';
  static const signIn       = '/signin';
  static const createSpace  = '/space/create';
  static const invite       = '/space/invite';
  static const acceptInvite = '/space/join/:token';
  static const tasks        = '/tasks';
}
```

---

## Deep Link — Invite Flow

Firebase Dynamic Links is deprecated. We use **App Links (Android)** and **Universal Links (iOS)** with a Cloud Function serving the required verification files.

### How it works

```
Owner taps "Share invite"
  → App generates invite token (stored in Firestore)
  → Builds link: https://sharedtasks.app/join/{token}
  → Opens native share sheet

Partner taps link
  ├── App installed → OS intercepts → opens AcceptInviteScreen(token)
  └── App not installed → browser opens → Cloud Function serves
        ├── Android: /.well-known/assetlinks.json  → redirects to Play Store
        └── iOS:     /.well-known/apple-app-site-association → redirects to App Store

After install, partner opens app manually
  → App checks Firestore for pending invite token on first launch
  → If valid token found → AcceptInviteScreen shown automatically
```

### Required setup

**Android — `assetlinks.json`** hosted at `https://sharedtasks.app/.well-known/assetlinks.json`

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.madhusangita.shared_tasks",
    "sha256_cert_fingerprints": ["YOUR_SHA256_HERE"]
  }
}]
```

**iOS — `apple-app-site-association`** hosted at `https://sharedtasks.app/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAMID.com.madhusangita.sharedTasks",
      "paths": ["/join/*"]
    }]
  }
}
```

**Cloud Function** serves these files and handles the fallback redirect to stores.

> ⚠️ A custom domain is required for App Links + Universal Links. Use a free domain or GitHub Pages to host the `/.well-known/` files for MVP 1.

---

## Firebase Setup

### Collections

```
users/                          ← one doc per authenticated user
spaces/                         ← one doc per shared space
spaces/{spaceId}/tasks/         ← subcollection, all tasks for a space
```

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users — read own doc, write own doc only
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    // Spaces — only members can read/write
    match /spaces/{spaceId} {
      allow read: if request.auth.uid in resource.data.memberUids;
      allow create: if request.auth.uid == request.resource.data.ownerUid;
      allow update: if request.auth.uid in resource.data.memberUids;
      allow delete: if request.auth.uid == resource.data.ownerUid;

      // Tasks — only space members can read/write
      match /tasks/{taskId} {
        allow read, write: if request.auth.uid in
          get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberUids;
      }
    }

    // Invite join — allow authenticated user to read space by token
    // (handled via Cloud Function to keep token validation server-side)
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
  firebase_core: ^2.27.0
  firebase_auth: ^4.19.0
  cloud_firestore: ^4.17.0
  firebase_messaging: ^14.9.0
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

### Running tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Single feature
flutter test test/unit/features/tasks/
```

---

## Conventions

| Thing | Convention |
|---|---|
| Files | `snake_case.dart` |
| Classes | `PascalCase` |
| Providers | `camelCaseProvider` |
| Routes | defined in `AppRoutes` constants only |
| Firestore field names | `camelCase` strings in `FirestoreConstants` |
| Commit messages | Conventional commits: `feat:` `fix:` `chore:` `test:` `docs:` |
| Branch names | `feat/us-XX-short-description` |

---

## Feature Build Order (MVP 1)

Build in this sequence — each feature depends on the previous:

1. `core/` — Result type, failures, theme, router, shared widgets
2. `auth/` — sign up, sign in, persistent session
3. `spaces/` — create space, space state
4. `invite/` — generate link, accept invite, deep link handling
5. `tasks/` — task list, add, edit, delete, assign, status, live sync
6. `functions/` — push notification on assignment

---

## ADR Log

> Architecture Decision Records — document significant decisions here as the project evolves.

**ADR-001** — Feature-first over layer-first  
*Reason:* Co-location of feature code improves Claude Code agent effectiveness and developer navigation. Layers still exist within each feature.

**ADR-002** — Manual Riverpod providers over code gen  
*Reason:* Eliminates build_runner step from the agentic workflow loop. Explicit providers are easier to read and debug.

**ADR-003** — Custom Result<T> sealed class over fpdart Either  
*Reason:* No third-party dependency. Dart 3 sealed classes + pattern matching give the same exhaustive handling with zero extra packages.

**ADR-004** — App Links + Universal Links over Branch.io  
*Reason:* No cost, no third-party SDK. Branch deprecated; Firebase Dynamic Links shutting down Aug 2025. Custom domain + Cloud Function serves verification files.

**ADR-005** — Firebase Emulator for tests, real project for dev  
*Reason:* Keeps test suite fast, isolated and free. Real project used for dev gives realistic Firestore behaviour during feature development.
