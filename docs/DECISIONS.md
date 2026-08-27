# Engineering Decisions Log

This document records significant decisions made during the development of SharedTasks — including decisions that were reversed. The goal is to capture the reasoning at each step so future contributors (and the author) understand not just what was decided but why, and what we learned.

---

## ADR-009 — Orchestrator approach: Python subprocess → Native Claude Code Skills

**Date:** August 2026  
**Status:** Superseded — see final decision below

---

### The original idea

We wanted an agentic development pipeline that could:
- Read a GitHub issue
- Plan the implementation
- Generate Flutter feature code
- Write tests
- Review code with a critic loop
- Commit and open a PR

With human checkpoints at every meaningful step — you approve the plan, review the code, test manually, approve the commit, approve the PR.

The showcase goal was to demonstrate this pipeline on GitHub so anyone could see how the app was built end-to-end using AI agents.

---

### Attempt 1 — Shell script

**Idea:** A bash script that chains `claude "..."` calls in sequence.

**Why we rejected it:**
- No context passing between steps — each agent is blind to what the previous one did
- No retry logic — if the critic finds issues, the script can't loop back to the coder
- No checkpoint mechanism — can't pause and wait for human approval
- Dumb pipe, not an orchestrator

---

### Attempt 2 — Python orchestrator with Anthropic SDK

**Idea:** A Python script using the `anthropic` Python SDK to call Claude API directly. Proper context passing, retry loops, structured JSON from the critic agent, checkpoints via `input()`.

**Why we rejected it:**
- The Anthropic SDK requires a separate API key with pay-as-you-go billing
- The project goal is to use Claude Pro subscription — no extra cost
- The Claude API and Claude Pro subscription are separate billing accounts

---

### Attempt 3 — Python orchestrator calling Claude Code CLI via subprocess

**Idea:** Keep the Python script but replace `anthropic.Anthropic()` calls with `subprocess.run("claude --print ...")`. This uses Claude Code CLI which is covered by Claude Pro.

**What we built:**
- Full Python orchestrator in `scripts/orchestrator.py`
- 7 human checkpoints
- Critic retry loop (up to 3 attempts)
- PyGithub for issue reading and PR creation
- Agent docs in `.ai-workflows/` as the source of truth for each agent's prompt

**Why we rejected it:**
- Claude Code CLI is designed for interactive terminal use — calling it via subprocess is fighting against its design
- `claude --print` and `claude -p` flags work but are unreliable in subprocess context
- Long timeouts, hanging processes (Claude Code would sometimes spawn `flutter run` which never exits)
- Hard to debug — errors are swallowed in subprocess output
- Not the intended use pattern — we were essentially building a wrapper around a tool that already has a better native way to do this

**The key lesson:** We were trying to orchestrate Claude Code from outside Claude Code. The right approach is to orchestrate from inside Claude Code using its native primitives.

---

### Final decision — Native Claude Code Skills

**What Claude Code provides natively (as of 2026):**

| Primitive | What it does |
|---|---|
| `CLAUDE.md` | Always-loaded project context — the agent's constitution |
| `Skills` (`SKILL.md` in `.claude/skills/`) | Loaded on demand — packages a repeatable workflow |
| `Subagents` | Isolated Claude instances spawned by the main session — own context window, own tools |
| `Hooks` | Deterministic scripts that fire at lifecycle events (PreToolUse, PostToolUse, on-Stop) |

**How the pipeline maps to native primitives:**

| Orchestrator concept | Native Claude Code equivalent |
|---|---|
| Python orchestrator | `/build-feature` Skill |
| Planner agent | Main session (reads CLAUDE.md + agent docs) |
| Coder agent | Subagent spawned by the skill |
| Test writer agent | Subagent spawned by the skill |
| Critic agent | Subagent + Hook on PostToolUse |
| Human checkpoints | Plan mode (`/plan`) + manual approval |
| Agent prompts | Individual SKILL.md files in `.claude/skills/` |

**Why this is better:**
- No subprocess hacks — this is what Claude Code was designed for
- No extra cost — covered by Claude Pro
- Faster — no overhead of spawning external processes
- Better context passing — subagents share the same session memory
- Checkpoints work naturally — Claude Code's Plan mode pauses for approval
- Skills are the single source of truth — change the SKILL.md, change the behaviour

**The showcase story:**
> "This project uses Claude Code's native Skills and subagent system to build each feature autonomously. The `.claude/skills/` folder contains the agent pipeline — anyone can clone the repo and run `/build-feature 15` to see the pipeline in action."

---

### What we kept from the Python orchestrator

The `scripts/orchestrator.py` file is preserved in the repository as a learning artifact. It demonstrates:
- How to build a human-in-the-loop pipeline with Python
- How to use PyGithub to read issues and open PRs programmatically  
- How to structure a multi-agent critic retry loop
- The checkpoint pattern for human oversight

It is **not used in production** — the native Skills pipeline replaced it. But it is documented and commented for educational value.

---

### Lessons learned

1. **Read the tool's documentation before building around it.** Claude Code has native orchestration primitives. We built a wrapper around the CLI before discovering this.

2. **Subprocess is a smell.** When you find yourself calling a CLI tool via subprocess to do what the tool already does natively, stop and ask if you're using the right abstraction.

3. **The showcase is stronger for this journey.** The decision log shows real engineering thinking — not just the happy path, but the iterations and the reasoning. That is more valuable than a polished demo that hides the false starts.

4. **Cost constraints shape architecture.** The decision to avoid the Anthropic SDK (to avoid extra billing) pushed us toward the subprocess approach, which ultimately led us to discover the right native approach. The constraint was a forcing function.
