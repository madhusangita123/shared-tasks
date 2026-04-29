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
│   ├── ARCHITECTURE.md        ← folder structure, patterns, Firestore schema
│   └── DECISIONS.md           ← ADRs (architecture decision records)
├── .ai-workflows/
│   ├── 01-prd-agent.md        ← how the PRD was generated
│   ├── 02-arch-agent.md       ← how the architecture was generated
│   ├── 03-codegen-agent.md    ← how features are generated from issues
│   └── 04-pr-agent.md        ← how PRs are written and opened
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart           ← MaterialApp, router setup
│   │   └── router.dart        ← go_router route definitions
│   ├── core/
│   │   ├── constants/         ← app-wide constants
│   │   ├── errors/            ← failure types
│   │   ├── extensions/        ← Dart extensions
│   │   └── utils/             ← helpers, formatters
│   ├── data/
│   │   ├── models/            ← Dart data classes (freezed)
│   │   ├── repositories/      ← repository implementations
│   │   └── datasources/       ← Firestore + Firebase Auth datasources
│   ├── domain/
│   │   ├── entities/          ← pure domain models
│   │   └── repositories/      ← repository interfaces (abstract)
│   └── presentation/
│       ├── auth/              ← sign up, sign in screens
│       ├── space/             ← create space, invite partner screens
│       ├── tasks/             ← task list, task detail screens
│       └── shared/            ← shared widgets, theme
├── test/
│   ├── unit/                  ← repository + model tests
│   └── widget/                ← widget tests
└── functions/                 ← Firebase Cloud Functions (push notifications)
```

---

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter 3.x, Dart |
| State management | Riverpod (flutter_riverpod) |
| Navigation | go_router |
| Backend | Firebase (Auth, Firestore, Cloud Messaging) |
| Code generation | freezed, json_serializable, riverpod_generator |
| Dependency injection | Riverpod providers |
| Testing | flutter_test, mocktail |

---

## Architecture pattern

Clean Architecture with 3 layers:

1. **Data** — Firestore datasources + repository implementations
2. **Domain** — entities + repository interfaces (no Flutter imports)
3. **Presentation** — screens + widgets + Riverpod providers

Rules:
- Domain layer has zero dependencies on Flutter or Firebase
- Data layer implements domain interfaces
- Presentation layer only calls domain interfaces via providers
- Never call Firestore directly from a widget

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

- **File naming:** snake_case for all files
- **Class naming:** PascalCase
- **Provider naming:** `camelCaseProvider`
- **Models:** use `freezed` for all data classes — immutable, copyWith, equality
- **Async:** use `AsyncValue` from Riverpod, never raw Future in UI
- **Error handling:** return `Either<Failure, T>` from repositories (use `fpdart`)
- **No business logic in widgets** — widgets call providers, providers call repositories
- **Every new file gets a corresponding test file**

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
