# SharedTasks — Claude Code Briefing

> Read this file before every session. It is the single source of truth for this project.

---

## What this project is

SharedTasks is a Flutter mobile app built primarily for households — couples and families
managing shared responsibilities like chores, errands, and kids' activities. Each person
owns their task lists and can share any of them with whoever's involved (partner, a sibling,
a kid, a housemate). Everyone on a shared space can add tasks, assign them to themselves or
any member, update status, and see each other's changes in real time — without refreshing
or messaging.

This is a personal project AND a GitHub portfolio showcase demonstrating an end-to-end
agentic development pipeline: PRD → Architecture → Code → Tests → PR.

---

## Repository structure

```
shared-tasks/
├── CLAUDE.md                       ← you are here
├── README.md
├── LICENSE                         ← MIT
├── docs/
│   ├── SharedTasks_MVP1_PRD.md     ← product requirements, read before writing any feature
│   ├── ARCHITECTURE.md             ← full architecture, patterns, Firestore schema, ADRs
│   ├── DECISIONS.md                ← architecture decision records (also in ARCHITECTURE.md)
│   └── FIREBASE_SETUP.md           ← Firebase project setup notes
├── .ai-workflows/
│   ├── 01-prd-agent.md
│   ├── 02-arch-agent.md
│   ├── 03-github-issues-agent.md
│   ├── 04-claudecode-agent.md
│   ├── 05-test-writer-agent.md
│   ├── 06-code-review-agent.md
│   ├── 07-pr-creation-agent.md
│   └── 08-readme-agent.md
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
│       ├── auth/               ← Google sign-in only
│       │   ├── data/          ← datasource, repository impl
│       │   ├── domain/        ← entity, repository interface
│       │   └── presentation/  ← providers, screens
│       ├── home/               ← all-spaces list (private + shared)
│       ├── spaces/             ← create space, space settings
│       ├── invite/             ← deep-link share/join
│       └── tasks/
├── test/
│   ├── unit/features/         ← repository + entity tests per feature
│   └── widget/features/       ← widget tests per feature
└── functions/                 ← Firebase Cloud Functions (not yet built — MVP 1 step 7)
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
| Deep links | `app_links` package — custom URI scheme `sharedtasks://join/{token}` (ADR-004, revised) |
| Testing | flutter_test, mocktail, Firebase Emulator |

---

## Architecture pattern

**Feature-first Clean Architecture.** Each feature (`auth`, `home`, `spaces`, `invite`, `tasks`) is self-contained with its own data, domain, and presentation layers. Shared infrastructure lives in `core/`.

Layer rules within each feature:
- `domain/` — pure Dart, zero Flutter or Firebase imports. Entities + repository interfaces only.
- `data/` — implements domain interfaces. All Firestore and Firebase Auth calls live here.
- `presentation/` — screens, widgets, Riverpod providers. Never calls Firestore directly.

Always read `docs/ARCHITECTURE.md` before writing any feature code.

---

## Firestore data model

```
users/{uid}
  displayName: string        ← from Google profile
  email: string               ← from Google profile
  photoUrl: string?           ← from Google profile
  fcmToken: string?
  createdAt: timestamp

spaces/{spaceId}
  name: string
  ownerUid: string
  memberUids: string[]
  inviteToken: string
  inviteExpiresAt: timestamp  ← 1 year from generation, multi-use until then
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

> Note: users no longer have a `spaceId` field. To find all spaces for a user, query `spaces` where `memberUids` contains the user's uid.

---

## MVP 1 screens

| ID | Name | Route |
|---|---|---|
| S-01 | Sign in | `/signin` — logo, tagline, "Continue with Google" only |
| S-02 | Home | `/home` — all spaces (private + shared), FAB to create |
| S-03 | Task list | `/space/:spaceId/tasks` — grouped by status |
| S-04 | Task detail | slide-up sheet (no route) — edit, assign, status |
| S-05 | Create space | `/space/create` |
| S-06 | Space settings | `/space/:spaceId/settings` — members, Share, regenerate link |
| S-07 | Accept invite | `/join/:token` — auto-resolved on deep link, no explicit UI |

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
- **Feature build order:** core → auth → home → spaces → invite → tasks → functions

---

## Key user stories (MVP 1)

- US-01 Sign in with Google — no email/password, no account creation
- US-02 Home screen — all spaces (private + shared) in one place
- US-03 Create a named space — private by default
- US-04 Share a space via deep link with anyone — 1 year, multi-use, no accept screen
- US-05 Add, edit, delete tasks
- US-06 Assign task to self or any space member → push notification fires
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
- Email / password sign-in (Google sign-in only — ADR-006)
- Apple sign-in
- Guest / anonymous mode
- Removing a member from a space
- Resharing by recipients
- Due dates or reminders
- Task comments or attachments
- AI suggestions
- Activity history
- Tablet or web support
- Offline writes (read-only offline is in scope)

---

## Product roadmap

| Version | Focus |
|---|---|
| MVP 1 | Google sign-in, multiple spaces per user, share any space with anyone, core task flow ← we are here |
| MVP 2 | Remove a member, resharing by recipients, transfer space ownership |
| MVP 3 | Due dates, comments, attachments, activity log, fair-share digest |
| MVP 4 | AI layer — natural language input, smart suggestions, auto-categorize |

---

## How to work on this project

### Starting a new feature
1. Read the relevant user story in `docs/SharedTasks_MVP1_PRD.md`
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
- [x] Architecture doc written (v2.0, Approved)
- [x] GitHub issues created for MVP 1 (issues #1–#16)
- [ ] Firebase project created and connected — dev/prod projects exist, app boots cleanly with Firebase on iOS + Android (issue #1 / PR #18); Google-only Auth toggle and Android SHA-256/OAuth consent screen still need manual confirmation in Firebase Console
- [ ] Features built — `core/` infrastructure done (issue #2); `auth`, `home`, `spaces`, `invite`, `tasks` not yet built

---

## Owner

GitHub: madhusangita123
Project started: April 2026