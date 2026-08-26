# 08 — README Agent

## Purpose

Generates the GitHub README for the SharedTasks repository. This is the front door of the showcase — the first thing anyone sees when they visit the repo. Run once when the app is ready to showcase, and updated as features are added.

**Input:** `docs/PRD.md` + `docs/ARCHITECTURE.md` + `.ai-workflows/` folder  
**Output:** `README.md` at the repo root

---

## When to Run

This is a **one-time agent**, not part of the per-feature pipeline. Run it:
- When MVP 1 is complete and ready to showcase
- When significant new features land (MVP 2, MVP 3)
- When the agentic pipeline changes significantly

---

## Claude API Prompt

```
You are a senior developer writing a GitHub README for a portfolio project.

The project is SharedTasks — a Flutter mobile app for household task management,
built end-to-end using an agentic AI development pipeline.

Read the following:
- docs/PRD.md
- docs/ARCHITECTURE.md
- .ai-workflows/ folder (all agent docs)

Write a README.md that tells two stories simultaneously:
1. The product story — what SharedTasks is and why it exists
2. The engineering story — how it was built using AI agents

Follow this structure exactly:

# SharedTasks

[One line tagline]

[Demo GIF placeholder — add: ![Demo](docs/demo.gif)]

## The product
[3-4 sentences. Problem it solves. Who uses it. Core features.]

## Features
[Bullet list of MVP 1 features — concise, user-facing language]

## The agentic pipeline
[This is the showcase section — explain the pipeline clearly]
[Include a diagram using ASCII or mermaid]
[Explain each agent's role in 1-2 sentences]
[Show the orchestrator flow with checkpoints]

## Tech stack
[Table: layer → choice → reason]

## Architecture
[Feature-first Clean Architecture explanation]
[Folder structure — top level only, not every file]

## Running the project
[Prerequisites]
[Setup steps]
[How to run the orchestrator]

## Agent docs
[Table linking to each .ai-workflows/ doc with one line description]

## Roadmap
[MVP 1 / MVP 2 / MVP 3 / MVP 4 table]

Rules:
- Write for a senior engineer audience — no hand-holding
- The agentic pipeline section must be the most detailed — it is the showcase
- Include exact commands — no vague instructions
- Keep total length under 600 lines
- No emojis except in the features list
- Respond with ONLY the markdown. No preamble.
```

---

## Input from Orchestrator

```python
context = {
    "prd": read_file("docs/PRD.md"),
    "architecture": read_file("docs/ARCHITECTURE.md"),
    "agent_docs": list_files(".ai-workflows/"),
    "features_built": completed_issues,   # list of merged PRs
}
```

---

## Success Criteria

- `README.md` exists at repo root
- Contains all 8 sections from the structure above
- Agentic pipeline section includes a diagram
- All links to `.ai-workflows/` docs are valid
- `flutter pub get && flutter run` works when following the setup steps

---

## What This Agent Does NOT Do

- Does not generate screenshots or GIFs — you add those manually
- Does not update the README on every PR — run manually when needed
- Does not create docs pages — README only

---

## Previous Agent

👈 [`07-pr-creation-agent.md`](./07-pr-creation-agent.md) — PR Creation Agent

## Next Agent

👉 [`09-firebase-setup-agent.md`](./09-firebase-setup-agent.md) — Firebase Setup Agent
