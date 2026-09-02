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

Based on the issue and the architecture docs, draft a detailed plan:
1. Feature name and folder (`lib/features/[feature]/`)
2. Complete file list with one-line description each
3. Git branch name: `feat/us-$1-short-description`
4. Build order — which file first, second, etc.
5. Each acceptance criteria mapped to specific files
6. Test files to create

---

## Step 2a — Check for hidden dependencies; decompose if needed

Before presenting the plan for approval, assess whether fully implementing this issue needs infrastructure or capabilities that don't exist anywhere in the repo yet — a new backend (Cloud Functions), a new external package with native platform setup, a new Firestore collection whose security-rule design is non-trivial, a new third-party service. This is different from "just more files in this feature's folder" — it's a dependency the plan would otherwise have to silently build inline, expanding scope past what the issue asked for.

If no such dependency exists, skip straight to Checkpoint 1 with the plan from Step 2.

If one does exist:
1. **Identify each distinct unit of dependency work** as its own buildable issue — infra setup, the capability itself, and the feature that consumes it are usually separate units, even if related.
2. **Explain the tradeoff to the user** before creating anything — what the dependency is for, why it's needed, what the alternative(s) are (e.g., a narrower client-only design vs. a server-side one), and the cost of each. Let the user decide; don't silently pick one. If asked to justify a recommendation, explain the actual reasoning (security/trust boundary, maintenance burden, what else already needs this same capability) rather than just restating the recommendation.
3. Once the user has chosen a direction, **create one GitHub issue per unit**, in dependency order, each following `.ai-workflows/03-github-issues-agent.md`'s body template (User Story or Purpose / Acceptance Criteria / Technical Notes with an explicit `Depends on:` / Definition of Done) and correct labels.
4. **Link each as a native GitHub sub-issue** of the original issue via the GraphQL API:
   ```bash
   # Get the parent issue's node id once:
   gh api graphql -f query='query { repository(owner: "OWNER", name: "REPO") { issue(number: N) { id } } }'
   # Then for each sub-issue:
   gh api graphql -f query='mutation { addSubIssue(input: {issueId: "PARENT_NODE_ID", subIssueUrl: "https://github.com/OWNER/REPO/issues/M"}) { subIssue { number title } } }'
   ```
   (Confirm sub-issues are supported first — query `repository { issue(number: N) { subIssues(first: 1) { totalCount } } }`; if that errors, fall back to a plain checklist in a comment instead.)
5. **Post a comment on the original issue** summarizing the breakdown in implementation order, and leave it open as the tracking parent — it closes naturally once every sub-issue is merged.
6. **Redirect the pipeline to the first unblocked sub-issue** — re-run Step 1 (fetch) and Step 2 (plan) for that sub-issue's actual number, and present Checkpoint 1 for that plan, not the original umbrella issue. Continue the rest of this pipeline (Steps 3–9) per sub-issue, one at a time, in dependency order, exactly as if each had been `/build-feature`'d individually.

**CHECKPOINT 1 — Show the plan (for the issue actually being built) and wait for approval.**
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
- Never silently expand an issue's scope to cover a missing dependency (a new backend, a non-trivial security-rule design, a new external service) — surface it via Step 2a and get the user's direction first
