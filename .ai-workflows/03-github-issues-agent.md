# 03 — GitHub Issues Agent

## Purpose

Transforms an approved PRD and architecture document into a set of well-structured GitHub Issues — one per user story — with labels, milestones, and acceptance criteria ready for development.

**Input:** `docs/PRD.md` + `docs/ARCHITECTURE.md`  
**Output:** GitHub Issues created directly in your repository via GitHub MCP

---

## Prerequisites

Before running this agent you need:

1. **GitHub Personal Access Token (PAT)** with `repo` scope
   - github.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Scopes needed: `repo` (full)
   - Copy the token — shown once only

2. **Claude Code CLI installed** — this agent runs in terminal, not VS Code panel

3. **GitHub MCP connected via terminal**

```bash
claude mcp add github-mcp-server 
  
export GITHUB_PERSONAL_ACCESS_TOKEN=your_token_here

claude mcp add github-mcp-server -s local -- npx -y @modelcontextprotocol/server-github

# Verify
claude mcp list
# Should show: github-mcp-server ✓
```

---

## ⚠️ Important — MCP Only Works in Terminal

The Claude Code VS Code extension does **not** support MCP servers. This is a known limitation.
GitHub Issues and PR creation agents **must be run from the terminal**.

Use the VS Code integrated terminal (`Ctrl+`` ` or Terminal → New Terminal) — you get the best
of both worlds: VS Code open for context, terminal for MCP-powered commands.

## How to Run

### Terminal (required for this agent)

**Step 1 — Connect GitHub MCP**
```bash
claude mcp add github-mcp-server \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=your_token_here
```

Verify it's connected:
```bash
claude mcp list
# Should show: github-mcp-server ✓
```

**Step 2 — Run the agent**
```bash
cd your-project
claude "Read docs/PRD.md and docs/ARCHITECTURE.md.

Create GitHub Issues in madhusangina123/shared-tasks for every user story 
in the PRD. Follow these rules:

1. One issue per user story (US-01 through US-09)
2. Issue title format: [US-XX] Short description
3. Issue body must include:
   - User story statement
   - Full acceptance criteria from the PRD as a checklist
   - Technical notes from the architecture doc relevant to this story
   - Files to create based on feature-first folder structure
   - Definition of done
4. Apply labels: feat, chore, or test as appropriate
5. Add all issues to milestone: MVP 1 — create it first if it does not exist
6. Link dependent issues

After creating all issues, print a summary table with issue numbers and URLs."
```

> 💡 **Tip:** Keep VS Code open while the terminal runs. You can watch Claude create
> issues in real time and check them on GitHub simultaneously.

---

## GitHub Labels to Create First

Create these labels in your repo before running the agent.
Go to github.com/madhusangina123/shared-tasks/labels and add:

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

## Expected Issues — SharedTasks MVP 1

The agent should create exactly these issues:

| Issue | Title | Label | Depends on |
|---|---|---|---|
| #1 | [CHORE] Flutter project setup and folder structure | `chore` | — |
| #2 | [CHORE] Firebase project setup and emulator config | `chore` | #1 |
| #3 | [CHORE] Core — Result type, failures, theme, router, shared widgets | `chore` | #1 |
| #4 | [US-01] Account creation — sign up screen | `feat` | #2 #3 |
| #5 | [US-02] Sign in with persistent session | `feat` | #4 |
| #6 | [US-03] Create a space | `feat` | #5 |
| #7 | [US-04] Invite partner via deep link | `feat` | #6 |
| #8 | [US-05] Add, edit, delete tasks | `feat` | #6 |
| #9 | [US-06] Assign task to self or partner | `feat` | #8 |
| #10 | [US-07] Update task status | `feat` | #8 |
| #11 | [US-08] Live sync via Firestore listeners | `feat` | #8 |
| #12 | [US-09] Push notifications on assignment | `feat` | #9 #2 |

---

## Issue Body Template

Each issue the agent creates should follow this structure:

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

## Definition of Done
- [ ] All acceptance criteria checked
- [ ] Unit tests written and passing
- [ ] Widget tests written and passing
- [ ] `flutter test` passes with no failures
- [ ] Code reviewed (self-review against Dart best practices)
- [ ] PR opened and linked to this issue
```

---

## Milestone Setup

Create this milestone before running the agent:

| Field | Value |
|---|---|
| Title | MVP 1 |
| Description | Core shared task list — one space, two people, live sync |
| Due date | Set your target date |

---

## Actual Output — SharedTasks

Issues created at:  
🔗 [github.com/madhusangina123/shared-tasks/issues](https://github.com/madhusangina123/shared-tasks/issues)

---

## What This Agent Does NOT Do

- Does not write Flutter code (that is agent 04 — Claude Code agent)
- Does not create branches (Claude Code agent handles that per issue)
- Does not estimate story points — keep issues small enough that each one is 1-2 days of work
- Does not create issues for MVP 2 features — those go in a separate milestone

---

## Previous Agent

👈 [`02-arch-agent.md`](./02-arch-agent.md) — Architecture Agent

## Next Agent

👉 [`04-claudecode-agent.md`](./04-claudecode-agent.md) — Claude Code Agent
