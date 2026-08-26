# 07 — PR Creation Agent

## Purpose

Writes a rich PR description and opens the pull request on GitHub. Called by the orchestrator after Checkpoint 6 (commit approved) and Checkpoint 7 (PR approved by you).

**Input:** Feature code + review output + GitHub issue + commit hash  
**Output:** Pull request opened on GitHub with full description, linked to issue

---

## ⚠️ Important — Needs GitHub Access

The orchestrator opens the PR using **PyGithub** directly — no MCP needed here. The Python script calls the GitHub API with your token.

---

## Claude API Prompt

```
You are a senior Flutter engineer writing a pull request description.

Read the following:
- The GitHub issue: [issue body]
- Files changed: [list of files]
- Commit message: [commit message]
- Code review summary: [critic agent summary]

Write a pull request description in this exact format:

## Summary
[2-3 sentences describing what this PR implements and why]

## Changes
[Bullet list of every file created or modified with one line explaining what it does]

## How to test
[Step by step instructions for a reviewer to manually test this feature]

## Acceptance criteria
[Copy the acceptance criteria checklist from the issue — mark each as done]

## Notes
[Any known limitations, follow-up issues, or decisions made during implementation]

## Closes
Closes #[issue number]

Rules:
- Be specific — no vague descriptions
- How to test must be actionable — exact steps, not "run the app"
- Notes must include any deviations from the original issue scope
- Keep it under 500 words total

Respond with ONLY the PR description markdown. No preamble.
```

---

## How the Orchestrator Opens the PR

```python
from github import Github

def create_pr(branch, title, body, issue_number):
    g = Github(os.getenv("GITHUB_TOKEN"))
    repo = g.get_repo("madhusangina123/shared-tasks")
    
    pr = repo.create_pull(
        title=title,
        body=body,
        head=branch,
        base="main",
    )
    
    # Link to issue
    issue = repo.get_issue(issue_number)
    issue.create_comment(f"PR opened: {pr.html_url}")
    
    return pr.html_url
```

---

## PR Title Format

```
[US-XX] Short description of what was implemented

Examples:
[US-01] Sign in with Google
[US-02] Home screen — all spaces list
[CHORE] Core layer — Result type, theme, router
```

---

## Input from Orchestrator

```python
context = {
    "issue_number": issue_number,
    "issue_body": github_issue.body,
    "branch": current_branch,          # feat/us-XX-short-description
    "commit_hash": git_commit_hash,
    "files_changed": list_changed_files(),
    "commit_message": commit_message,
    "review_summary": critic_output.summary,
}
```

---

## Success Criteria

Orchestrator considers this agent successful when:
- PR is opened on GitHub without error
- PR is linked to the correct issue
- PR URL is returned and shown to you at Checkpoint 7

---

## What This Agent Does NOT Do

- Does not merge the PR — you do that on GitHub after review
- Does not request reviewers — solo project
- Does not run any tests — orchestrator already verified those
- Does not modify any code

---

## Previous Agent

👈 [`06-code-review-agent.md`](./06-code-review-agent.md) — Code Review Agent

## Next Agent

👉 [`08-readme-agent.md`](./08-readme-agent.md) — README Agent
