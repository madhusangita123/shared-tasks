---
name: build-feature
description: |
  Builds a complete Flutter feature end-to-end from a GitHub issue number.
  Reads the issue, plans the implementation, generates code, writes tests,
  reviews code with a critic loop, and prepares a PR.
  Use when the user says "build issue #N", "implement issue #N", or "/build-feature N".
trigger: build issue, implement issue, build feature
arguments:
  - name: issue
    description: GitHub issue number (e.g. 15)
    required: true
---

# Build Feature Pipeline

You are the lead orchestrator for the SharedTasks agentic development pipeline.
Your job is to build a complete Flutter feature from a single GitHub issue number.

Read these files before doing anything else:
- `CLAUDE.md` — project conventions, architecture rules, feature build order
- `docs/PRD.md` — product requirements
- `docs/ARCHITECTURE.md` — architecture patterns, data model, Firestore rules
- `.ai-workflows/04-claudecode-agent.md` — coder agent instructions
- `.ai-workflows/05-test-writer-agent.md` — test writer instructions
- `.ai-workflows/06-code-review-agent.md` — critic agent instructions
- `.ai-workflows/07-pr-creation-agent.md` — PR writer instructions

---

## Step 1 — Fetch the issue

Use the GitHub MCP to read issue #$1 from madhusangina123/shared-tasks.
Extract: title, body, acceptance criteria, labels, dependencies.

---

## Step 2 — Create implementation plan

Based on the issue and the architecture docs, create a detailed plan:
1. Feature name and folder (`lib/features/[feature]/`)
2. Complete file list with one-line description each
3. Git branch name: `feat/us-$1-short-description`
4. Build order — which file first, second, etc.
5. Each acceptance criteria mapped to specific files
6. Test files to create

**CHECKPOINT 1 — Show the plan and wait for approval.**
Type the plan clearly and ask: "Type 'y' to proceed or describe changes needed."
Do not proceed until the user approves.

---

## Step 3 — Create feature branch

```bash
git checkout -b feat/us-$1-short-description
```

---

## Step 4 — Generate feature code (Coder subagent)

Spawn a subagent to implement the feature. Pass it:
- The approved plan
- The issue body
- Instructions from `.ai-workflows/04-claudecode-agent.md`

The subagent must:
- Follow feature-first folder structure
- Use `Result<T>` for all repository returns
- Use manual Riverpod providers only
- Run `dart run build_runner build --delete-conflicting-outputs` after any freezed model
- Run `flutter analyze` — fix ALL issues before finishing
- Create empty test stubs in `test/` for every file
- NOT commit

After the subagent completes, run `flutter analyze` and show the results.

**CHECKPOINT 2 — Show generated files and analyze output.**
Ask: "Open VS Code and review the files. Type 'y' when happy or describe issues."
Do not proceed until the user approves.

---

## Step 5 — Manual testing

**CHECKPOINT 3 — Ask user to test manually.**
Show: "Run `flutter run` and test the feature on your device."
Show the acceptance criteria from the issue.
Ask: "Type 'y' when satisfied or describe issues found."
Do not proceed until the user approves.

---

## Step 6 — Write tests (Test Writer subagent)

Spawn a subagent to write tests. Pass it:
- The list of generated feature files
- Instructions from `.ai-workflows/05-test-writer-agent.md`

The subagent must:
- Write unit tests in `test/unit/features/[feature]/`
- Write widget tests in `test/widget/features/[feature]/`
- Use mocktail — never real Firebase
- Test success AND failure cases
- Run `flutter test` — fix any failures

After the subagent completes, show the test results.

**CHECKPOINT 4 — Show test results.**
Ask: "Review test files in VS Code. Type 'y' to proceed or describe issues."
Do not proceed until the user approves.

---

## Step 7 — Code review (Critic subagent, up to 3 retries)

Spawn a subagent to review the code and tests. Pass it:
- All feature files
- All test files  
- Instructions from `.ai-workflows/06-code-review-agent.md`

The subagent must respond with JSON:
```json
{
  "status": "clean" | "issues_found",
  "summary": "one sentence",
  "issues": [{"severity": "critical|warning", "file": "...", "description": "...", "fix": "..."}],
  "suggestions": []
}
```

If `issues_found`: spawn the Coder subagent to fix, then re-run Critic. Max 3 retries.
If still `issues_found` after 3 retries: show issues and ask user to intervene.

**CHECKPOINT 5 — Show review results.**
Ask: "Type 'y' to proceed to commit or describe additional fixes needed."
Do not proceed until the user approves.

---

## Step 8 — Commit

Show the user:
- Branch name
- Proposed commit message: `feat([feature]): [issue title cleaned up]`
- List of all files to be committed

**CHECKPOINT 6 — Commit approval.**
Ask: "Type 'y' to commit or provide a different commit message."
Only after approval:
```bash
git add .
git commit -m "feat([feature]): [description]"
git push origin [branch]
```

---

## Step 9 — Open PR (PR Writer subagent)

Spawn a subagent to write the PR description. Pass it:
- Issue title and body
- List of files changed
- Critic review summary
- Instructions from `.ai-workflows/07-pr-creation-agent.md`

Show the full PR description to the user.

**CHECKPOINT 7 — PR approval.**
Ask: "Type 'y' to open the PR or describe changes to the description."
Only after approval: use GitHub MCP to open the PR from the feature branch to main.
Post a comment on the issue linking to the PR.

---

## Done

Show a summary:
- Issue number and title
- Branch name
- Commit hash
- PR URL

Tell the user: "Review and merge the PR on GitHub."

---

## Rules

- Never skip a checkpoint — always wait for explicit 'y' approval
- Never commit without Checkpoint 6 approval
- Never open a PR without Checkpoint 7 approval  
- If the user types 'q' at any checkpoint — stop immediately
- If the user provides feedback instead of 'y' — use it to fix and show again
- Always follow the feature build order in `CLAUDE.md`
- Read agent docs from `.ai-workflows/` — they are the single source of truth
