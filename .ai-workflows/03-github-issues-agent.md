# 03 — GitHub Issues Agent

## Purpose

Transforms an approved PRD and architecture document into a set of well-structured GitHub Issues — one per user story — with labels, milestones, and acceptance criteria ready for development.

This agent has two modes:
- **Create** — fresh run, no existing issues
- **Sync** — PRD has changed, update existing issues to match

**Input:** `docs/PRD.md` + `docs/ARCHITECTURE.md`  
**Output:** GitHub Issues created/updated/closed directly in the repository via GitHub MCP

---

## ⚠️ Important — MCP Only Works in Terminal

The Claude Code VS Code extension does **not** support MCP servers. This is a known limitation.
This agent **must be run from the terminal**.

Use the VS Code integrated terminal (`Ctrl+\`` ` or Terminal → New Terminal).

---

## Prerequisites

1. **GitHub Personal Access Token (PAT)** with `repo` scope
   - github.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Scopes: `repo` (full)

2. **GitHub MCP connected**

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=your_token_here
claude mcp add github-mcp-server -s local -- npx -y @modelcontextprotocol/server-github

# Verify
claude mcp list
# Should show: github-mcp-server ✓ Connected
```

---

## Mode 1 — Create (fresh run)

Use when: no issues exist yet in the repo.

```bash
cd your-project
claude "Read docs/PRD.md and docs/ARCHITECTURE.md.

Create GitHub Issues in madhusangina123/shared-tasks for every user story in the PRD.

Follow these rules:
1. Create milestone 'MVP 1' if it does not exist
2. Create labels if they do not exist: feat, chore, test, bug, mvp-1, mvp-2, blocked
3. Create chore issues first (setup tasks), then one issue per user story
4. Issue title format: [CHORE] description or [US-XX] description
5. Issue body must follow the template in this file exactly
6. Apply correct labels and add to MVP 1 milestone
7. Note dependencies between issues in the body

Print a summary table when done."
```

---

## Mode 2 — Sync (PRD has changed)

Use when: issues already exist but PRD has been updated. This is the primary mode for this project — PRD is now v2.0 and existing issues reflect v1.0.

```bash
cd your-project
claude "Read docs/PRD.md (v2.0) and docs/ARCHITECTURE.md carefully.

Then list all open issues in madhusangina123/shared-tasks.

Compare every existing issue against the current PRD and do the following:

CLOSE these issues with comment 'Closed: replaced by PRD v2.0':
- Any issue for email/password sign up or sign in
- Any issue that no longer matches a user story in the current PRD

UPDATE these issues to match PRD v2.0:
- Update title, body, acceptance criteria for any issue whose scope has changed
- Add comment explaining what changed and why

CREATE new issues for user stories in PRD v2.0 that have no existing issue:
- [US-01] Sign in with Google
- [US-02] Home screen — all spaces list
- [US-03] Create a space
- [US-04] Share a space via deep link
- [US-05] Manage tasks
- [US-06] Assign a task
- [US-07] Update task status
- [US-08] Live sync
- [US-09] Push notifications
- [CHORE] Firebase project setup
- [CHORE] Core layer setup
- [CHORE] Firebase emulator setup

For every issue (new or updated), use the issue body template below.
Add all issues to the MVP 1 milestone.
Apply correct labels.

Print a summary table when done: issue number, title, action taken (closed/updated/created), URL."
```

---

## Issue Body Template

Every issue must follow this structure exactly:

```markdown
## User Story
As a [user], I want to [action] so that [outcome].

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Notes
- Feature folder: `lib/features/[feature]/`
- Files to create:
  - `lib/features/[feature]/domain/entities/[entity].dart`
  - `lib/features/[feature]/domain/repositories/[repo].dart`
  - `lib/features/[feature]/data/datasources/[datasource].dart`
  - `lib/features/[feature]/data/repositories/[repo_impl].dart`
  - `lib/features/[feature]/presentation/providers/[provider].dart`
  - `lib/features/[feature]/presentation/[screen].dart`
  - `test/unit/features/[feature]/[repo]_test.dart`
  - `test/widget/features/[feature]/[screen]_test.dart`
- Relevant patterns: see `docs/ARCHITECTURE.md`
- Depends on: #issue-number (if applicable)

## Definition of Done
- [ ] All acceptance criteria checked
- [ ] flutter analyze passes with zero errors
- [ ] Unit tests written and passing
- [ ] Widget tests written and passing
- [ ] flutter test passes with no failures
- [ ] PR opened and linked to this issue
```

---

## Expected Issues — SharedTasks MVP 1 (v2.0)

After sync, the repo should have exactly these open issues:

| Title | Label | Depends on |
|---|---|---|
| [CHORE] Flutter project setup and folder structure | `chore mvp-1` | — |
| [CHORE] Firebase project setup and emulator config | `chore mvp-1` | above |
| [CHORE] Core layer — Result type, theme, router, shared widgets | `chore mvp-1` | above |
| [US-01] Sign in with Google | `feat mvp-1` | chores |
| [US-02] Home screen — all spaces list | `feat mvp-1` | US-01 |
| [US-03] Create a named space | `feat mvp-1` | US-02 |
| [US-04] Share a space via deep link | `feat mvp-1` | US-03 |
| [US-05] Manage tasks — add, edit, delete | `feat mvp-1` | US-03 |
| [US-06] Assign a task to self or any member | `feat mvp-1` | US-05 |
| [US-07] Update task status | `feat mvp-1` | US-05 |
| [US-08] Live sync via Firestore listeners | `feat mvp-1` | US-05 |
| [US-09] Push notifications on assignment | `feat mvp-1` | US-06 |

---

## GitHub Labels

| Label | Color | Description |
|---|---|---|
| `feat` | `#0075ca` | New feature |
| `chore` | `#e4e669` | Setup, config, tooling |
| `test` | `#d93f0b` | Tests only |
| `bug` | `#d73a4a` | Something isn't working |
| `mvp-1` | `#0e8a16` | In scope for MVP 1 |
| `mvp-2` | `#bfd4f2` | Deferred to MVP 2 |
| `blocked` | `#b60205` | Blocked by another issue |

---

## What This Agent Does NOT Do

- Does not write Flutter code — that is agent 04
- Does not create branches — Claude Code agent handles that per issue
- Does not create issues for MVP 2 features — those go in a separate milestone
- Does not merge or close PRs

---

## Previous Agent

👈 [`02-arch-agent.md`](./02-arch-agent.md) — Architecture Agent

## Next Agent

👉 [`04-claudecode-agent.md`](./04-claudecode-agent.md) — Claude Code Agent
