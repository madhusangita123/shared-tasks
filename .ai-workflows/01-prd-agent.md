# 01 — PRD Agent

## Purpose

Transforms a raw product idea description into a structured, development-ready Product Requirements Document (PRD). This is the first agent in the SharedTasks agentic development pipeline.

**Input:** Natural language idea description  
**Output:** `docs/PRD.md` — full PRD with user stories, acceptance criteria, data model, screens, and NFRs

---

## How to Run

### Option 1 — Claude.ai chat (recommended for PRD)
1. Go to [claude.ai](https://claude.ai)
2. Start a new conversation
3. Paste the **System Prompt** below as your first message
4. Follow with the **Input Template** filled with your product idea
5. Iterate with follow-up messages to refine scope, edge cases, and decisions
6. Save the final output as `docs/PRD.md` in your repo

### Option 2 — Claude Code in VS Code
1. Open your project in VS Code
2. Click the **Claude Code icon** in the left sidebar
3. In the Claude Code panel, click **"New Session"**
4. Type the following prompt:

```
Act as a senior product manager. Ask me clarifying questions about my
product idea before writing anything. Once all questions are answered,
generate a complete PRD and save it as docs/PRD.md.
Follow the agent instructions and output format in .ai-workflows/01-prd-agent.md.
```

5. Answer the clarifying questions in the Claude Code chat panel
6. Claude Code will create `docs/PRD.md` directly in your project

### Option 3 — Claude Code in terminal
```bash
cd your-project
claude "Act as a senior product manager. Ask me clarifying questions about my product idea then generate docs/PRD.md. Follow .ai-workflows/01-prd-agent.md for the output format."
```

> 💡 **VS Code tip:** Create an empty `docs/` folder before running this agent so Claude Code knows where to save the output.

---

## System Prompt

```
You are a senior product manager with deep experience in mobile app development.
Your job is to take a product idea and produce a complete, development-ready PRD.

Follow these rules strictly:
- Ask clarifying questions before writing anything. Do not assume.
- Treat the person as a senior mobile product engineer — no hand-holding.
- Scope aggressively. Push non-essential features to future versions explicitly.
- Every user story must have concrete, testable acceptance criteria.
- Flag edge cases and constraint decisions with a ⚠ marker.
- Define the data model in terms of the chosen backend (Firebase Firestore).
- Define screens by ID (S-01, S-02...) — not wireframes, just names and purpose.
- Separate NFRs (non-functional requirements) with concrete measurable targets.
- End with a clear "Out of scope" list and a "Future versions" roadmap.

Output format:
# Product Name — PRD
## Problem Statement
## Goal
## Scope (In / Out)
## User Stories & Acceptance Criteria (US-01, US-02...)
## Task/Entity Status Model (if applicable)
## Data Model
## Screens
## Non-Functional Requirements
## Future Versions
## Next Steps
```

---

## Input Template

Fill this in and send it after the system prompt:

```
Product idea: [describe your app in 2-5 sentences]

Target users: [who will use this]

Core problem it solves: [the pain point]

Must-have for MVP: [list the features you cannot ship without]

Platform: [iOS / Android / Flutter / React Native etc.]

Backend preference: [Firebase / Supabase / custom etc.]

Anything explicitly out of scope: [what you do NOT want in v1]
```

---

## Actual Input Used — SharedTasks

```
Product idea: A Flutter mobile app where couples and households share a live 
task list. Members can add tasks, assign them to themselves or a partner, 
update status, and see each other's changes in real time.

Target users: Couples and small households (2-3 people) managing shared 
responsibilities — chores, errands, kids activities.

Core problem it solves: Tasks fall through the cracks. Nobody knows who's 
doing what right now. No single source of truth for "what needs doing" 
and "who's on it."

Must-have for MVP:
- Create account
- Create a task list (space)
- Share with a partner
- Add, edit, delete tasks
- Assign tasks to self or partner
- Task status: to do, in progress, done
- Live sync — partner sees changes instantly
- Push notification on assignment

Platform: Flutter (iOS + Android)
Backend: Firebase (Auth, Firestore, Cloud Messaging)

Out of scope for MVP:
- Multiple spaces per user
- More than 2 members
- Due dates, reminders
- Comments, attachments
- AI features
```

---

## Key Decisions Made During PRD Session

These were deliberated — not assumed. Document decisions like these for every project.

| Decision | Options considered | Choice | Reason |
|---|---|---|---|
| Invite flow | OTP code vs deep link only | Deep link only | Less friction, modern pattern, no typing required |
| Multiple spaces | MVP 1 vs MVP 2 | MVP 2 | Adds nav complexity, space switcher, dynamic member lists — out of scope for v1 |
| Multiple members | MVP 1 vs MVP 2 | MVP 2 | Assignment UI changes, notification fan-out, Firestore rules complexity |
| Status model | 2 states vs 3 states | 3 states (todo/in_progress/done) | "In progress" is the core visibility feature — knowing who's actively working on what |
| Delete confirmation | Always vs only in-progress | Only for in-progress tasks | Reduce friction for todo tasks, protect against accidental loss of active work |
| Status lock | Assignee only vs any member | Any member | Household context — partners need to close each other's tasks without friction |

---

## Clarifying Questions to Always Ask

Before writing any PRD, ask these. The answers change the output significantly.

1. **Invite model** — how do users get other people into the app? Email? Link? QR code?
2. **Ownership model** — can anyone edit anything, or is there role-based access?
3. **Conflict model** — what happens if two people edit the same thing simultaneously?
4. **Notification strategy** — notify on every change, or only on direct assignment?
5. **Offline behaviour** — read-only, full offline, or block writes with feedback?
6. **One-to-one vs one-to-many** — two people only, or N members?
7. **Scope boundary** — what is explicitly NOT in this version?

---

## Output

The PRD generated by this agent is saved at:

📄 [`docs/PRD.md`](../docs/PRD.md)

---

## What This Agent Does NOT Do

- Does not generate code
- Does not make architecture decisions (that is the next agent)
- Does not create GitHub issues (that is agent 03)
- Does not wireframe screens (deliberate — wireframes come after PRD is approved)

---

## Next Agent

Once the PRD is approved, run:

👉 [`02-arch-agent.md`](./02-arch-agent.md) — Architecture Agent