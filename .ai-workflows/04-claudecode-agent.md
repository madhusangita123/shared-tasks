# 04 — Claude Code Agent

## Purpose

Picks up a single GitHub Issue and generates a complete Flutter feature — entity, repository interface, repository implementation, Riverpod provider, screen/widget, and test files — following the architecture defined in `docs/ARCHITECTURE.md`.

**Input:** Single GitHub Issue number + `CLAUDE.md` + `docs/ARCHITECTURE.md` + `docs/PRD.md`  
**Output:** Full feature code committed to a feature branch, ready for test writing (agent 05)

---

## ⚠️ Important

- This agent runs in the **VS Code extension panel** — no MCP needed for code generation
- Run **one issue at a time** — do not ask it to build multiple features in one session
- Always build in the **feature build order** defined in `ARCHITECTURE.md`:
  `core → auth → spaces → invite → tasks → functions`
- Never skip ahead — each feature depends on the previous one being complete

---

## How to Run

### Option 1 — Claude Code VS Code Extension (recommended)

1. Open your project in VS Code
2. Click the **Claude Code icon** in the left sidebar
3. Click **"New Session"**
4. Use this prompt template — replace `#XX` with the issue number:

```
Read CLAUDE.md, docs/PRD.md and docs/ARCHITECTURE.md first.

Then implement GitHub Issue #XX in full.

Follow these rules strictly:
1. Create a feature branch: git checkout -b feat/us-XX-short-description
2. Follow feature-first folder structure — all files go inside lib/features/[feature]/
3. Build in this order for this feature:
   a. Domain entity (freezed)
   b. Repository interface (abstract)
   c. Remote datasource (Firestore/Firebase)
   d. Repository implementation
   e. Riverpod manual provider
   f. Screen or widget
4. Use Result<T> sealed class for all repository return types — never throw
5. Use manual Riverpod providers — no @riverpod code gen
6. Every file must have a corresponding test file created in test/
7. Run flutter analyze before finishing — fix all warnings and errors
8. Commit with message: feat(feature-name): implement US-XX short description
9. Do not open a PR — that is handled by a separate agent

When complete, list every file created and the git commit hash.
```

### Option 2 — Terminal

```bash
cd ~/Projects/shared-tasks
claude "Read CLAUDE.md, docs/PRD.md and docs/ARCHITECTURE.md then implement GitHub Issue #XX. Follow .ai-workflows/04-claudecode-agent.md strictly."
```

> 💡 **Tip:** Keep the GitHub issue open in your browser while Claude Code runs. You can follow along and catch anything that deviates from the acceptance criteria.

---

## Feature Build Order

Always work issues in this sequence. Do not skip.

| Order | Issue | Feature | Depends on |
|---|---|---|---|
| 1 | #13 | Flutter project setup | — |
| 2 | #1 | Firebase project setup | #13 |
| 3 | #2 | Core layer | #13 |
| 4 | #3 | Firebase Emulator setup | #1 #2 |
| 5 | #4 | US-01 Sign up | #2 #3 |
| 6 | #5 | US-02 Sign in | #4 |
| 7 | #6 | US-03 Create space | #5 |
| 8 | #7 | US-04 Invite partner | #6 |
| 9 | #8 | US-05 Manage tasks | #6 |
| 10 | #9 | US-06 Assign task | #8 |
| 11 | #10 | US-07 Update status | #8 |
| 12 | #11 | US-08 Live sync | #8 |
| 13 | #12 | US-09 Push notifications | #9 #1 |

---

## What Claude Code Will Generate Per Feature

For a typical feature like `tasks`, the agent creates:

```
lib/features/tasks/
├── domain/
│   ├── entities/
│   │   ├── task.dart                  ← freezed entity
│   │   └── task_status.dart           ← enum
│   └── repositories/
│       └── tasks_repository.dart      ← abstract interface
├── data/
│   ├── datasources/
│   │   └── tasks_remote_datasource.dart  ← Firestore calls
│   └── repositories/
│       └── tasks_repository_impl.dart    ← Result<T> returns
└── presentation/
    ├── providers/
    │   └── tasks_provider.dart           ← manual Riverpod providers
    ├── task_list_screen.dart
    └── task_detail_sheet.dart

test/
├── unit/features/tasks/
│   └── tasks_repository_test.dart
└── widget/features/tasks/
    └── task_list_screen_test.dart
```

---

## Rules Claude Code Must Follow

These are baked into the prompt but worth knowing explicitly:

**Architecture rules:**
- Domain entities: `freezed`, zero Flutter/Firebase imports
- Repository interfaces: `abstract interface class`, returns `Result<T>`
- Datasources: all Firestore/Firebase calls live here only
- Providers: manual `Provider`, `AsyncNotifierProvider`, `StreamProvider` — no code gen
- Screens: call providers only, never call repositories or Firestore directly

**Code quality rules:**
- No hardcoded strings — use `FirestoreConstants` for all Firestore field names
- No raw `Future` in widgets — always `AsyncValue`
- No `print()` statements
- `flutter analyze` must pass with zero errors before commit

**Git rules:**
- One branch per issue: `feat/us-XX-short-description`
- One commit per issue (squash if needed)
- Conventional commit format: `feat(feature): implement US-XX description`
- Never commit directly to `main`

---

## Reviewing the Output

After Claude Code finishes, check these before moving to the test writer agent:

- [ ] All files listed in the issue's "Files to create" section exist
- [ ] `flutter analyze` passes with zero errors
- [ ] No Firestore calls in presentation layer
- [ ] No hardcoded Firestore collection/field strings
- [ ] Result<T> used in all repository methods
- [ ] Feature branch created and committed
- [ ] Test files created (even if empty stubs)

---

## Common Issues and Fixes

**Claude Code goes off-script and uses a different pattern:**
```
Stop. Read CLAUDE.md again and check your implementation against the 
architecture rules. Fix any deviations before continuing.
```

**build_runner errors after freezed model created:**
```bash
dart run build_runner build --delete-conflicting-outputs
```

**flutter analyze errors:**
```
Run flutter analyze, read every error, fix them one by one. 
Do not proceed until analyze passes clean.
```

**Claude Code tries to build multiple features at once:**
```
Stop. Finish this single issue completely before touching anything else.
```

---

## Example Session — Issue #4 (US-01 Sign Up)

```
You: Read CLAUDE.md, docs/PRD.md and docs/ARCHITECTURE.md first.
     Then implement GitHub Issue #4 in full.
     [full prompt from above]

Claude Code:
  ✓ Reading CLAUDE.md...
  ✓ Reading docs/PRD.md...
  ✓ Reading docs/ARCHITECTURE.md...
  ✓ Creating branch feat/us-01-sign-up...
  ✓ Creating lib/features/auth/domain/entities/app_user.dart
  ✓ Creating lib/features/auth/domain/repositories/auth_repository.dart
  ✓ Creating lib/features/auth/data/datasources/auth_remote_datasource.dart
  ✓ Creating lib/features/auth/data/repositories/auth_repository_impl.dart
  ✓ Creating lib/features/auth/presentation/providers/auth_provider.dart
  ✓ Creating lib/features/auth/presentation/sign_up_screen.dart
  ✓ Creating test/unit/features/auth/auth_repository_test.dart
  ✓ Creating test/widget/features/auth/sign_up_screen_test.dart
  ✓ Running flutter analyze... clean
  ✓ Committed: feat(auth): implement US-01 sign up screen

  Files created: 8
  Commit: a3f2c1d
```

---

## What This Agent Does NOT Do

- Does not write tests (that is agent 05 — Test Writer)
- Does not review code (that is agent 06 — Code Review)
- Does not open PRs (that is agent 07 — PR Creation)
- Does not build multiple features in one session
- Does not modify `main` branch directly

---

## Previous Agent

👈 [`03-github-issues-agent.md`](./03-github-issues-agent.md) — GitHub Issues Agent

## Next Agent

👉 [`05-test-writer-agent.md`](./05-test-writer-agent.md) — Test Writer Agent
