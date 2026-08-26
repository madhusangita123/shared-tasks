# 06 — Code Review Agent (Critic)

## Purpose

Reviews generated feature code and tests together. Acts as a critic — finds issues, flags deviations from architecture, checks for security problems and performance issues. Called by the orchestrator after the Test Writer agent (05) completes. Runs up to 3 retry loops if issues are found.

**Input:** Feature code + test files + `docs/ARCHITECTURE.md` + `CLAUDE.md`  
**Output:** Structured review report — clean or issues list for Coder agent to fix

---

## Claude API Prompt

```
You are a senior Flutter engineer conducting a code review.
Your job is to review the feature code and tests provided critically and thoroughly.

Read the following:
- CLAUDE.md
- docs/ARCHITECTURE.md
- docs/PRD.md
- All files in lib/features/[feature]/
- All files in test/unit/features/[feature]/
- All files in test/widget/features/[feature]/

Review against these criteria:

ARCHITECTURE:
- [ ] Domain entities have zero Flutter/Firebase imports
- [ ] Repository interfaces use abstract interface class
- [ ] All repository methods return Result<T> — no throwing
- [ ] Datasources contain ALL Firestore/Firebase calls — nothing leaks into repositories or presentation
- [ ] Providers are manual — no @riverpod annotations
- [ ] Screens call providers only — never repositories or Firestore directly
- [ ] Home screen queries spaces via memberUids arrayContains — not user.spaceId
- [ ] Auth uses google_sign_in only — no email/password anywhere

CODE QUALITY:
- [ ] No hardcoded Firestore collection or field strings — all in FirestoreConstants
- [ ] No raw Future in widgets — AsyncValue used throughout
- [ ] No print() statements
- [ ] flutter analyze passes clean
- [ ] Meaningful variable and method names
- [ ] No unused imports or variables

TESTS:
- [ ] Every repository method has a test — success AND failure case
- [ ] Result<T> returns verified explicitly in tests
- [ ] No real Firebase or Google Sign-In in tests — all mocked
- [ ] Widget tests cover loading, error, and success states
- [ ] Tests are readable and descriptive

SECURITY:
- [ ] No API keys or tokens hardcoded
- [ ] No sensitive data logged
- [ ] Firestore writes properly scoped to authenticated user

Respond ONLY with a JSON object in this exact format:
{
  "status": "clean" | "issues_found",
  "summary": "One sentence summary",
  "issues": [
    {
      "severity": "critical" | "warning" | "suggestion",
      "file": "lib/features/auth/data/...",
      "line": 42,
      "description": "What is wrong",
      "fix": "How to fix it"
    }
  ],
  "approved_files": ["list of files that are good"],
  "retry_count": 0
}

If status is "clean", issues array must be empty.
Only include critical and warning issues in the issues array — suggestions are informational only.
```

---

## Retry Loop

The orchestrator runs this agent in a loop with a max of 3 retries:

```python
MAX_RETRIES = 3
retry_count = 0

while retry_count < MAX_RETRIES:
    review = critic_agent.review(code, tests)
    
    if review.status == "clean":
        break
    
    # Send issues back to coder agent to fix
    code = coder_agent.fix(review.issues)
    retry_count += 1
    review["retry_count"] = retry_count

if review.status != "clean" after 3 retries:
    # Pause and ask human to intervene
    checkpoint("Critic could not resolve issues after 3 retries. Please review manually.")
```

---

## Input from Orchestrator

```python
context = {
    "feature": feature_name,
    "feature_files": list_files("lib/features/[feature]/"),
    "test_files": list_files("test/unit/features/[feature]/") 
                + list_files("test/widget/features/[feature]/"),
    "architecture": read_file("docs/ARCHITECTURE.md"),
    "prd": read_file("docs/PRD.md"),
    "claude_md": read_file("CLAUDE.md"),
    "retry_count": retry_count,
}
```

---

## Success Criteria

Orchestrator considers this agent successful when:
- `status` is `"clean"` in the JSON response
- No `critical` or `warning` issues remain
- Reached within 3 retries

If 3 retries are exhausted — orchestrator pauses at a checkpoint and asks for human intervention.

---

## What This Agent Does NOT Do

- Does not modify any files — reports only
- Does not open PRs — that is agent 07
- Does not run `flutter test` — orchestrator handles that
- Does not review other features — scoped to current issue only

---

## Previous Agent

👈 [`05-test-writer-agent.md`](./05-test-writer-agent.md) — Test Writer Agent

## Next Agent

👉 [`07-pr-creation-agent.md`](./07-pr-creation-agent.md) — PR Creation Agent
