# SharedTasks

A real-time shared task app for households — couples, families, housemates. Create a space, share a link, and everyone sees changes as they happen.

Built with Flutter and Firebase. Every feature was implemented by an AI agent pipeline running against a fixed set of human approval gates — the workflow is documented below, including the parts that didn't work.

---

## Demo

> **TODO — add the walkthrough video here.**
> Drag the video file into a new GitHub issue comment (don't post it), copy the
> `https://github.com/user-attachments/...` URL it generates, and paste it on a
> line by itself below. GitHub renders it as an inline player.
>
> Worth showing: sign in → create a space → add tasks inline → assign one →
> the push notification arriving on a second device → dark mode.

---

## The problem

Shared household admin usually lives in a messaging thread. Someone asks "did you book the plumber?", it scrolls away, and two people buy milk.

SharedTasks gives a household one live list. Anyone in a space can add a task, assign it to a person, and change its status; everyone else sees it within about two seconds, with a push notification when they're assigned something. Sharing is a link — no accounts to create for the other person beyond Google sign-in, no invite codes to type.

**Screens:** sign in · all spaces · task list · task detail sheet · create space · space settings.

## Stack

| | |
|---|---|
| Framework | Flutter (Dart) |
| State | Riverpod — manual providers, no code generation |
| Backend | Firebase: Auth, Firestore, Cloud Messaging, Cloud Functions, Hosting |
| Navigation | `go_router` |
| Models | `freezed` |
| Errors | A custom `Result<T>` sealed type — repositories never throw |
| Tests | `flutter_test`, `mocktail`, Firebase Emulator Suite |

Feature-first clean architecture: each feature owns its `domain/`, `data/` and `presentation/` layers, with `core/` for shared infrastructure. Full detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), and the reasoning behind specific calls in [`docs/DECISIONS.md`](docs/DECISIONS.md).

---

## How it was built

The interesting part of this repo isn't the task app. It's that the code was written by AI agents inside a pipeline I could actually supervise.

### The pipeline

One command — `/build-feature 55` — takes a GitHub issue number and runs it to a pull request. It's a [222-line markdown skill](.claude/skills/build-feature/SKILL.md), not a program.

```
Read issue → Plan ──▶ ① approve plan
                         │
              Coder ──▶ ② review generated code
                         │
        Manual test ──▶ ③ confirm it works on a real device
                         │
        Test Writer ──▶ ④ review tests
                         │
      Critic (×1–3) ──▶ ⑤ review findings
                         │
             Commit ──▶ ⑥ approve commit
                         │
          PR Writer ──▶ ⑦ approve PR
```

Each ① – ⑦ is a hard stop. Nothing proceeds without an explicit `y`.

### The agents

| Agent | Job | Briefed by |
|---|---|---|
| **Coder** | Implements the issue against the approved plan | [`04-claudecode-agent.md`](.ai-workflows/04-claudecode-agent.md) |
| **Test Writer** | Writes unit and widget tests, no real Firebase | [`05-test-writer-agent.md`](.ai-workflows/05-test-writer-agent.md) |
| **Critic** | Independent review, returns structured JSON; up to 3 fix rounds | [`06-code-review-agent.md`](.ai-workflows/06-code-review-agent.md) |
| **PR Writer** | Drafts the PR description | [`07-pr-creation-agent.md`](.ai-workflows/07-pr-creation-agent.md) |

Earlier stages — PRD, architecture, issue breakdown — have their own agent briefs in [`.ai-workflows/`](.ai-workflows/).

The Critic runs as a *separate* agent with no memory of writing the code. That separation is what makes it useful: it found a race between two widgets sharing one provider, and a write-failure path that silently dropped a user's edit. Neither was visible to static analysis or a passing test suite.

### The orchestrator I threw away

The first version of this was [`scripts/orchestrator.py`](scripts/orchestrator.py) — **940 lines of Python** driving subprocesses, parsing JSON between stages, managing retries and timeouts.

It worked. I replaced it with **222 lines of markdown**.

The Python encoded the workflow as control flow, so every change meant editing a program. The skill describes the same workflow as instructions, so changing it means editing prose. Same seven checkpoints, same agents, a fraction of the machinery. The file is still in the repo as the before-picture.

---

## By the numbers

Roughly a month of evenings, 27 August – 26 September.

| | |
|---|---|
| Merged PRs | 32 |
| Closed issues | 31 |
| Production code | 6,817 lines across 74 files |
| Test code | 9,398 lines across 50 files |
| Tests | 465 |
| Test-to-code ratio | 1.38 : 1 |

---

## What worked

**Tests didn't get skipped.** The pipeline produced more test code than production code. Whatever else is true, the "I'll add tests later" failure mode didn't happen.

**Behaviour survived rewrites.** The task list redesign replaced a 591-line screen wholesale and kept the notification deep-link, the entrance animation and the delete-with-undo flow intact — because tests from those earlier issues were still there and failed loudly when touched.

**The code explains itself.** There are 25 comments in `lib/` of the form *"without this, X breaks silently"* — why an offline guard must set state, why a SnackBar needs `persist: false`, why iOS needs an anchor rect or the share sheet never appears. That's the part that survives being handed to another person.

**Independent review earned its place.** A fresh agent reviewing code it hadn't written caught concurrency bugs that a green test suite did not.

## What didn't

**Green tests, broken screen.** This was the dominant failure mode. On the task list redesign alone, with 409 tests passing: an add row that stuck in edit mode forever — the issue's *own* acceptance criterion was unreachable — plus a grey box inherited from a global theme default, an IME underline, and a wrong icon. On the detail sheet, merely opening a task silently reordered the home screen. **Every user-visible bug this month was caught by a human looking at a device, not by the test suite.**

**The same mistake recurred.** A `←` character rendered nearly invisibly at body size. Found on a device in one issue, then written again in the next. Agents don't carry lessons forward unless the lesson is written down — it's now a comment in two files.

**Tests that guarded nothing — twice.** One test passed with the code it tested fully deleted. Another passed with its guard removed. Both were only caught by deliberately reverting the fix to see whether the test noticed. Tests written by the same process that wrote the code can be confidently, silently wrong.

**A review false positive cost three failed fixes.** The Critic reported a bug that didn't exist. I built a fix, hit three successive failures chasing it, then proved the original claim was wrong and deleted the code. Net negative work, entirely downstream of trusting a confident report.

**Review rounds tracked statefulness, not size.** A large visual rewrite passed in one round. A small sheet with overlapping async writes took three — each round finding a genuine defect in the *same twenty lines*.

**Agents did unrequested work.** One reformatted four unrelated files on its way past. Caught only by reading the diff.

## What I'd do differently

1. **Treat "tests pass" as the start of verification, not the end.** The checkpoint that caught real bugs was always ③, on a device.
2. **Verify a test fails without its fix.** Deleting the implementation and re-running is cheap, and it's the only thing that distinguishes a guard from decoration.
3. **Write findings into the codebase, not the chat.** Anything not committed as a comment gets re-learned the hard way.
4. **Treat a confident review as a hypothesis.** Reproduce before fixing.
5. **Read every diff, including the parts nobody asked for.**

---

## Running it

```bash
flutter pub get
flutter run
```

Unit and widget tests need no backend — Firebase is mocked with `mocktail`:

```bash
flutter test
```

### Firebase emulators

Integration tests and manual testing against a local backend use the Emulator Suite:

```bash
./scripts/emulators.sh     # wrapper; pins the JDK the emulators need
# or
firebase emulators:start --only firestore,auth
```

Emulator UI: http://127.0.0.1:4000 · Auth: `127.0.0.1:9099` · Firestore: `127.0.0.1:8080`

Setup notes are in [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).

---

## Repo layout

```
lib/
  core/              Result<T>, theme, router, shared widgets, constants
  features/          auth · home · spaces · invite · tasks · notifications
    <feature>/
      domain/        entities + repository interfaces (pure Dart)
      data/          Firestore datasources + repository implementations
      presentation/  screens, widgets, Riverpod providers
functions/           Cloud Functions (invite join, assignment notifications)
test/                unit + widget tests mirroring lib/
.ai-workflows/       agent briefs for each pipeline stage
.claude/skills/      the build-feature pipeline
docs/                PRD, architecture, decisions, Firebase setup
scripts/             emulator wrapper, and the orchestrator that got replaced
```

---

## Status

MVP 1 is feature-complete: Google sign-in, multiple spaces, share-by-link, the full task flow with assignment, status and live sync, and push notifications on assignment.

Open work is tracked in [issues](https://github.com/madhusangita123/shared-tasks/issues) — currently a space-delete flow, a Firestore rules tightening, iOS universal links, and CI distribution.
