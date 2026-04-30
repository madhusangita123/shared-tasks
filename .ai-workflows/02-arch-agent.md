# 02 — Architecture Agent

## Purpose

Transforms an approved PRD into a complete architecture document covering folder structure, patterns, data model, security rules, environment setup, and all key technical decisions.

**Input:** `docs/PRD.md` + answers to clarifying questions  
**Output:** `docs/ARCHITECTURE.md` — full architecture reference for the project

---

## How to Run

### Option 1 — Claude.ai chat (recommended for Architecture)
1. Go to [claude.ai](https://claude.ai)
2. Start a new conversation
3. Paste the **System Prompt** below as your first message
4. Paste the contents of your `docs/PRD.md` as the second message
5. Answer the clarifying questions the agent asks — do not skip this step
6. Save the final output as `docs/ARCHITECTURE.md`

### Option 2 — Claude Code in VS Code
1. Open your project in VS Code
2. Click the **Claude Code icon** in the left sidebar
3. In the Claude Code panel, click **"New Session"**
4. Type the following prompt — Claude Code will automatically read your project files:

```
Read docs/PRD.md then act as a senior mobile platform architect.
Ask me clarifying questions about folder structure, state management,
error handling, navigation, deep links, and Firebase environment setup
before generating the architecture document.
Once all questions are answered, produce the full architecture document
and save it as docs/ARCHITECTURE.md.
Follow the output format defined in .ai-workflows/02-arch-agent.md.
```

5. Answer the clarifying questions in the Claude Code chat panel
6. Claude Code will create `docs/ARCHITECTURE.md` directly in your project

### Option 3 — Claude Code in terminal
```bash
cd your-project
claude "Read docs/PRD.md then ask me clarifying questions about the architecture before generating docs/ARCHITECTURE.md. Follow the agent instructions in .ai-workflows/02-arch-agent.md."
```

> 💡 **VS Code tip:** Keep `docs/PRD.md` open in the editor while running this agent. Claude Code uses open files as additional context hints.

---

## System Prompt

```
You are a senior mobile platform architect with deep expertise in Flutter, 
Firebase, and clean architecture patterns.

Your job is to take an approved PRD and produce a complete architecture document 
that a senior engineer or an AI coding agent (Claude Code) can follow without 
ambiguity.

Before writing anything, ask clarifying questions. Do not assume answers to:
- Folder structure preference (feature-first vs layer-first)
- State management style (code gen vs manual)
- Error handling pattern (Either, Result, exceptions)
- Navigation library choice
- Deep link strategy
- Local development setup (emulator vs real project)
- Any third-party SDKs vs building custom

Rules:
- Treat the person as a senior mobile product engineer — no hand-holding.
- Every architectural decision must be documented in an ADR log with the 
  reason and alternatives considered.
- Include concrete code examples for every pattern — not pseudocode, real Dart.
- Define the complete Firestore security rules.
- Define the feature build order explicitly.
- Call out what is explicitly NOT to be built in this version.
- The output must be usable as context for Claude Code with zero ambiguity.

Output format:
# Architecture Document
## Overview
## Folder Structure (annotated, every file)
## Core Patterns (with real Dart code examples)
## Navigation
## Deep Link Strategy
## Firebase Setup (collections, security rules, environments)
## pubspec.yaml dependencies
## Code Generation instructions
## Testing Strategy
## Conventions table
## Feature Build Order
## ADR Log
```

---

## Clarifying Questions to Always Ask

These questions were asked during the SharedTasks architecture session. Always ask them — the answers fundamentally change the output.

| Question | Why it matters |
|---|---|
| Feature-first or layer-first folders? | Changes the entire folder structure and how Claude Code navigates the project |
| Riverpod code gen or manual providers? | Code gen adds build_runner step that breaks agentic workflow loop |
| Error handling — Either, Result, or exceptions? | Affects every repository method signature |
| Navigation — go_router or auto_route? | auto_route requires code gen; go_router is explicit |
| Deep link strategy? | Firebase Dynamic Links is deprecated — must choose replacement |
| Firebase Emulator or real project for dev/test? | Affects test setup, CI config, and data isolation |
| Freezed for models? | Affects pubspec, build_runner usage, model patterns |

---

## Actual Decisions Made — SharedTasks

| Decision | Options Considered | Choice | Reason |
|---|---|---|---|
| Folder structure | Layer-first vs feature-first | Feature-first | Co-locates feature code, Claude Code stays in one folder per feature, easier to navigate |
| Riverpod style | Code gen (`@riverpod`) vs manual | Manual providers | Eliminates build_runner from agentic loop. Explicit, readable, no generated files for providers |
| Error handling | `fpdart Either<Failure,T>` vs custom `Result<T>` vs exceptions | Custom `Result<T>` sealed class | No third-party dependency. Dart 3 sealed classes + pattern matching give same exhaustive handling |
| Navigation | go_router vs auto_route | go_router | No code gen required. Explicit route config. Well supported. |
| Deep links | Firebase Dynamic Links vs Branch.io vs App Links/Universal Links | App Links + Universal Links | FDL deprecated Aug 2025. Branch.io costs money. Custom = free, no third party, full control |
| Firebase environments | Emulator only vs real only vs both | Both — emulator for tests, real for dev | Clean separation. Tests are fast, free, isolated. Dev gets realistic Firestore behaviour |
| Models | Manual vs freezed | freezed + json_serializable | Immutable, copyWith, equality, fromJson — all generated. Worth the build_runner step for models |

---

## Actual Input Used — SharedTasks

The PRD passed to this agent: [`docs/PRD.md`](../docs/PRD.md)

---

## Output

The architecture document generated by this agent is saved at:

📄 [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md)

---

## Key Sections in the Output

A good architecture doc from this agent must include:

- **Annotated folder structure** — every file listed with a comment explaining its purpose
- **Result<T> sealed class** — with real Dart 3 code, not pseudocode
- **Repository interface + implementation examples** — shows the domain/data split clearly
- **Riverpod provider examples** — all 3 types: Provider, AsyncNotifierProvider, StreamProvider
- **go_router config** — with auth redirect logic
- **Firestore security rules** — complete, not a placeholder
- **Firebase environment table** — dev / test (emulator) / prod
- **pubspec.yaml** — exact package versions
- **Feature build order** — numbered sequence, not optional
- **ADR log** — every decision documented with alternatives

---

## What This Agent Does NOT Do

- Does not generate Flutter code (that is agent 04 — Claude Code agent)
- Does not create GitHub issues (that is agent 03)
- Does not make product decisions — PRD must be approved before running this agent
- Does not pick third-party packages without asking

---

## Red Flags — When to Stop and Ask Again

If the PRD is unclear on any of these, stop and clarify before generating the architecture:

- Auth model is undefined (who can read/write what)
- Realtime requirements are vague (polling vs websockets vs Firestore listeners)
- Invite/sharing model is unclear (link? code? email?)
- Offline behaviour is not specified
- Platform targets are not confirmed (iOS version, Android version)

---

## Previous Agent

👈 [`01-prd-agent.md`](./01-prd-agent.md) — PRD Agent

## Next Agent

👉 [`03-github-issues-agent.md`](./03-github-issues-agent.md) — GitHub Issues Agent
