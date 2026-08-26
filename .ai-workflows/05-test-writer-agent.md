# 05 — Test Writer Agent

## Purpose

Reads generated feature code and writes comprehensive unit and widget tests. Called by the orchestrator after the Coder agent (04) completes and you have approved the code at Checkpoint 2.

**Input:** Generated feature code in `lib/features/[feature]/` + `docs/ARCHITECTURE.md`  
**Output:** Test files in `test/unit/features/[feature]/` and `test/widget/features/[feature]/`

---

## Claude API Prompt

```
You are a Flutter test engineer. Your job is to write comprehensive tests 
for the feature code provided.

Read the following files:
- CLAUDE.md
- docs/ARCHITECTURE.md  
- All files in lib/features/[feature]/

Write tests following these rules:

UNIT TESTS (test/unit/features/[feature]/):
1. Test every repository method — success and failure cases
2. Use mocktail to mock datasources
3. Test Result<T> returns — verify Success and Failure cases explicitly
4. Test every entity method and factory if present
5. One test file per repository

WIDGET TESTS (test/widget/features/[feature]/):
1. Test every screen — renders correctly, handles loading, handles error
2. Mock all providers using ProviderScope overrides
3. Test user interactions — taps, text input, navigation triggers
4. Test empty states and error states
5. One test file per screen

RULES:
- Never use real Firebase in tests — always mock
- Never use real Google Sign-In in tests — always mock
- Group tests with descriptive group() blocks
- Every test has a clear descriptive name
- Run flutter test after writing — fix any failures before finishing
- Do not modify any file in lib/ — tests only

When complete:
- List every test file created
- Show flutter test output
- Report: X tests written, Y passing, Z failing
```

---

## Input from Orchestrator

```python
# orchestrator.py passes these to the agent
context = {
    "feature": feature_name,           # e.g. "auth"
    "files_created": coder_output,     # list of files from coder agent
    "architecture": read_file("docs/ARCHITECTURE.md"),
    "claude_md": read_file("CLAUDE.md"),
}
```

---

## Success Criteria

Orchestrator considers this agent successful when:
- At least one test file per feature layer (unit + widget)
- `flutter test` exits with code 0 (all passing)
- No test imports from `lib/` internals that bypass the repository layer

---

## Test File Structure

```
test/
├── unit/features/[feature]/
│   └── [feature]_repository_test.dart
└── widget/features/[feature]/
    └── [screen]_test.dart
```

---

## What This Agent Does NOT Do

- Does not modify any code in `lib/`
- Does not write integration tests (MVP 2)
- Does not write tests for other features
- Does not commit — orchestrator handles commits at Checkpoint 6

---

## Previous Agent

👈 [`04-claudecode-agent.md`](./04-claudecode-agent.md) — Claude Code Agent

## Next Agent

👉 [`06-code-review-agent.md`](./06-code-review-agent.md) — Code Review Agent
