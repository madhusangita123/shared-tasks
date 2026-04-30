# SharedTasks — Claude Code Briefing

> Read this file before every session. It is the single source of truth for this project.

---

## What this project is

SharedTasks is a Flutter mobile app for couples and households to share a live task list.
Members can add tasks, assign them to themselves or a partner, update status, and see
each other's changes in real time — without refreshing or messaging.

This is a personal project AND a GitHub portfolio showcase demonstrating an end-to-end
agentic development pipeline: PRD → Architecture → Code → Tests → PR.

---

## Repository structure

```
shared-tasks/
├── CLAUDE.md                  ← you are here
├── README.md
├── LICENSE                    ← MIT
├── docs/
│   ├── PRD.md                 ← product requirements, read before writing any feature
│   ├── ARCHITECTURE.md        ← full architecture, patterns, Firestore schema, ADRs
│   └── DECISIONS.md           ← architecture decision records (also in ARCHITECTURE.md)
├── .ai-workflows/
│   ├── 01-prd-agent.md
│   ├── 02-arch-agent.md
│   ├── 03-codegen-agent.md
│   └── 04-pr-agent.md
├── lib/
│   ├── main.dart              ← entry point, Firebase init, ProviderScope
│   ├── app.dart               ← MaterialApp.router, theme
│   ├── core/                  ← shared across all features
│   │   ├── errors/            ← Result<T> sealed class, AppFailure types
│   │   ├── constants/         ← Firestore field names, app constants
│   │   ├── extensions/        ← Dart extensions
│   │   ├── theme/             ← AppTheme, AppColors
│   │   ├── router/            ← go_router config, AppRoutes constants
│   │   └── widgets/           ← shared widgets (AppButton, AppTextField)
│   └── features/              ← one folder per feature
│       ├── auth/
│       │   ├── data/          ← datasource, repository impl
│       │   ├── domain/        ← entity, repository interface
│       │   └── presentation/  ← providers, screens
│       ├── spaces/
│       ├── invite/
│       └── tasks/
├── test/
│   ├── unit/features/         ← repository + entity tests per feature
│   └── widget/features/       ← widget tests per feature
└── functions/                 ← Firebase Cloud Functions
```

---

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.x, Dart |
| State management | Riverpod — manual providers (no code gen) |
| Navigation | go_router |
| Backend | Firebase (Auth, Firestore, Cloud Messaging) |
| Models | freezed + json_serializable |
| Error handling | Custom Result<T> sealed class — no fpdart |
| Deep links | App Links (Android) + Universal Links (iOS) |
| Testing | flutter_test, mocktail, Firebase Emulator |

---

## Architecture pattern

**Feature-first Clean Architecture.** Each feature (`auth`, `spaces`, `invite`, `tasks`) is self-contained with its own data, domain, and presentation layers. Shared infrastructure lives in `core/`.

Layer rules within each feature:
- `domain/` — pure Dart, zero Flutter or Firebase imports. Entities + repository interfaces only.
- `data/` — implements domain interfaces. All Firestore and Firebase Auth calls live here.
- `presentation/` — screens, widgets, Riverpod providers. Never calls Firestore directly.

Always read `docs/ARCHITECTURE.md` before writing any feature code.

---

## Firestore data model

```
users/{uid}
  displayName: string
  email: string
  spaceId: string?
  fcmToken: string?
  createdAt: timestamp

spaces/{spaceId}
  name: string
  ownerUid: string
  memberUids: string[]
  inviteToken: string
  inviteExpiresAt: timestamp
  inviteUsedAt: timestamp?   ← set when partner joins, link becomes invalid
  createdAt: timestamp

spaces/{spaceId}/tasks/{taskId}
  title: string
  notes: string?
  status: 'todo' | 'in_progress' | 'done'
  assigneeUid: string?
  createdBy: string
  createdAt: timestamp
  updatedAt: timestamp
```

---

## MVP 1 screens

| ID | Name | Route |
|---|---|---|
| S-01 | Sign up | `/signup` |
| S-02 | Sign in | `/signin` |
| S-03 | Create space | `/space/create` |
| S-04 | Invite partner | `/space/invite` |
| S-05 | Task list | `/tasks` |
| S-06 | Task detail | bottom sheet (no route) |

---

## Coding conventions

- **File naming:** `snake_case.dart` for all files
- **Class naming:** `PascalCase`
- **Provider naming:** `camelCaseProvider`
- **Models:** `freezed` for all entities — immutable, copyWith, equality, fromJson
- **Error handling:** `Result<T>` custom sealed class — `Success<T>` or `Failure<T>`. Never throw from a repository. Never return null for errors.
- **Async in UI:** use `AsyncValue` from Riverpod — never raw `Future` in widgets
- **Riverpod:** manual providers only — no `@riverpod` code gen, no `build_runner` for providers
- **No business logic in widgets** — widgets call providers, providers call repositories
- **Firestore field names:** always use constants from `FirestoreConstants` — never hardcode strings
- **Every new file gets a corresponding test file**
- **Feature build order:** core → auth → spaces → invite → tasks → functions

---

## Key user stories (MVP 1)

- US-01 Account creation (email + password)
- US-02 Sign in with persistent session
- US-03 Create a named space
- US-04 Invite partner via deep link (native share sheet) — single use, expires 48hrs
- US-05 Add, edit, delete tasks
- US-06 Assign task to self or partner → push notification fires
- US-07 Update status: todo → in_progress → done → todo
- US-08 Live sync via Firestore listeners (≤2s latency)
- US-09 Push notification on assignment only

---

## Non-functional requirements

- Sync latency: ≤ 2 seconds on 4G
- Cold start: ≤ 2 seconds
- Platforms: iOS 16+, Android 12+
- Offline: read-only (cached data, writes blocked with feedback)
- Security: Firestore rules — members only read/write their own space

---

## What is OUT of scope for MVP 1

Do not implement these unless explicitly asked:
- Google / Apple sign-in
- Multiple spaces per user
- More than 2 members per space
- Due dates or reminders
- Task comments or attachments
- AI suggestions
- Activity history
- Tablet or web support

---

## Product roadmap

| Version | Focus |
|---|---|
| MVP 1 | One space, two people, core task flow ← we are here |
| MVP 2 | Multiple spaces per user, multiple members per space |
| MVP 3 | Due dates, comments, attachments, activity log |
| MVP 4 | AI layer — natural language input, smart suggestions |

---

## How to work on this project

### Starting a new feature
1. Read the relevant user story in `docs/PRD.md`
2. Check `docs/ARCHITECTURE.md` for patterns
3. Create feature branch: `git checkout -b feat/us-XX-short-description`
4. Write model → repository interface → repository impl → provider → widget → tests
5. Run `flutter test` — all tests must pass before committing
6. Commit with conventional commits: `feat:`, `fix:`, `chore:`, `test:`

### Commit message format
```
feat(tasks): add swipe-to-delete with undo snackbar

- Implements US-05 delete acceptance criteria
- Uses Dismissible widget with SnackBar undo action
- Adds unit test for delete repository method
```

### Running the project
```bash
flutter pub get
flutter run
```

### Running tests
```bash
flutter test
flutter test --coverage
```

---

## Current status

- [x] Flutter project scaffolded
- [x] Repo created and pushed to GitHub
- [ ] Firebase project created and connected
- [ ] Architecture doc written
- [ ] GitHub issues created for MVP 1
- [ ] Features built

---

## Owner

GitHub: madhusangita123
Project started: April 2026