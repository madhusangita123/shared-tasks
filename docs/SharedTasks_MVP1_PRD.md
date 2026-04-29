# SharedTasks — Product Requirements Document
**Version:** MVP 1.0  
**Status:** Draft  
**Date:** April 2026  
**Stack:** Flutter · Firebase

---

## Problem Statement

Couples and households manage shared responsibilities — chores, errands, kids' activities — through a mix of WhatsApp messages, mental load, and verbal reminders. Tasks fall through the cracks. Nobody knows who's doing what right now. There is no single source of truth for "what needs doing" and "who's on it."

---

## Goal

Ship a focused mobile app where two or more people share a live task list. Anyone can add tasks, assign them to themselves or a partner, update status, and see each other's changes in real time — without refreshing, polling, or messaging.

---

## Scope

### In scope (MVP 1)
- Account creation (email + password)
- Create a named task list (space)
- Invite a partner via shareable link
- Add, edit, delete tasks
- Assign task to self or a partner
- Task status: To do → In progress → Done
- Live sync (all members see changes instantly)
- Push notifications on assignment

### Out of scope (MVP 1)
- Google / Apple sign-in
- Multiple spaces per user
- Due dates and reminders
- Task comments or attachments
- AI suggestions
- Activity history / audit log
- Tablet / web support
- Offline mode

---

## User Stories & Acceptance Criteria

### US-01 — Account creation
> "As a new user, I want to create an account so I can start a shared task list."

- Sign-up screen collects name, email, password. Password min 8 chars.
- Duplicate email shows inline error before submission.
- On success, user lands on the Create Space screen.
- ⚠ Error states for weak password and network failure are shown inline — no modal dialogs.

---

### US-02 — Sign in
> "As a returning user, I want to sign in and land exactly where I left off."

- Persistent session — app does not ask for credentials again after first login unless explicitly signed out.
- Returning user deep-links to their space's task list directly.
- Forgot password triggers Firebase reset email.

---

### US-03 — Create a space
> "As a user without a space, I want to create one and name it so my list has context."

- Space name is required, 3–40 characters.
- Creator is automatically set as owner and the first member.
- After creation, user is taken to the (empty) task list screen.

---

### US-04 — Invite a partner
> "As the owner, I want to invite my partner so we share the same list."

- Invite screen generates a unique deep link (e.g. `sharedtasks://join/ABC123`).
- Owner shares the link via any app (WhatsApp, iMessage, etc.) using the native share sheet.
- Partner taps the link:
  - **App installed** → opens directly to "You've been invited to join [Space Name]" acceptance screen → tap Accept → they're in.
  - **App not installed** → redirected to App Store / Play Store → after install and first open, the invite acceptance screen appears automatically.
- Link expires after first use or 48 hours — whichever comes first. Single use only.
- Owner can regenerate a new link at any time from the invite screen.
- Space shows both members' display names once partner joins.
- ⚠ A user can only belong to one space in MVP 1. Tapping an invite link when already in a space shows a clear error.

---

### US-05 — Manage tasks
> "As any member, I want to add, edit, and delete tasks so the list stays accurate."

- Add task: title required (max 120 chars), optional notes (max 500 chars).
- Edit: tap task → slide-up sheet with editable fields.
- Delete: swipe-to-delete with undo snackbar (5-second window).
- Any member can add, edit, delete any task.
- ⚠ Deleting a task that is "In progress" shows a confirmation prompt first.

---

### US-06 — Assign a task
> "As any member, I want to assign a task to myself or my partner so ownership is clear."

- Tap task → assignment section shows all space members as tappable avatars.
- "Assign to me" is the first and most prominent option.
- Assigning to a partner triggers a push notification: "[Name] assigned you: [task title]".
- Assigned member's avatar is shown on the task card in the list view.
- Task can be reassigned at any time. Previous assignee gets no notification on reassign.
- ⚠ Unassigned tasks show a neutral "unassigned" state — not a warning.

---

### US-07 — Update task status
> "As the assignee, I want to mark a task in-progress or done so my partner knows where things stand."

- Status cycle: To do → In progress → Done. Done → To do is allowed (reopen).
- Status change is accessible from both the task card (quick tap) and the detail sheet.
- Any member can change status on any task — not locked to assignee.
- Done tasks move to a collapsed "Completed" section at the bottom of the list.
- ⚠ Partner sees status change in under 2 seconds on a standard connection.

---

### US-08 — Live sync
> "As any member, I want to see my partner's changes without refreshing."

- All task mutations (add, edit, delete, assign, status change) propagate to all members in real time via Firestore listeners.
- New and changed task cards animate subtly when they update (no jarring full-list reload).
- Optimistic local update on mutation — UI reflects change before server confirms.
- ⚠ Conflict: last write wins. No merge UI in MVP 1.

---

### US-09 — Push notifications
> "As a member, I want to be notified when a task is assigned to me."

- Notification fires only on assignment — not on every task change.
- Tapping the notification deep-links directly to that task's detail sheet.
- Notification permission is requested after the user joins or creates their first space.
- ⚠ If permission denied, app functions normally — no repeated permission prompts.

---

## Task Status Model

```
todo  →  in_progress  →  done
done  →  todo  (reopen)
```

Stored as `todo | in_progress | done` in Firestore.

---

## Data Model (Firestore)

### `users/{uid}`
| Field | Type |
|---|---|
| displayName | string |
| email | string |
| spaceId | string? |
| fcmToken | string? |
| createdAt | timestamp |

### `spaces/{spaceId}`
| Field | Type |
|---|---|
| name | string |
| ownerUid | string |
| memberUids | string[] |
| inviteToken | string |
| inviteExpiresAt | timestamp |
| inviteUsedAt | timestamp? |
| createdAt | timestamp |

### `spaces/{spaceId}/tasks/{taskId}`
| Field | Type |
|---|---|
| title | string |
| notes | string? |
| status | enum: todo \| in_progress \| done |
| assigneeUid | string? |
| createdBy | string |
| createdAt | timestamp |
| updatedAt | timestamp |

---

## Screens (MVP 1)

| ID | Name | Description |
|---|---|---|
| S-01 | Sign up | Name, email, password. Link to sign in. |
| S-02 | Sign in | Email, password. Forgot password link. |
| S-03 | Create space | Space name input. Shown once per account. |
| S-04 | Invite partner | Deep link share sheet. Regenerate option. |
| S-05 | Task list | Live list grouped by status. FAB to add task. |
| S-06 | Task detail | Slide-up sheet. Edit, assign, status change. |

---

## Non-Functional Requirements

| Requirement | Target |
|---|---|
| Sync latency | ≤ 2 seconds (partner sees task change on 4G) |
| App cold start | ≤ 2 seconds (open to task list visible) |
| Platforms | iOS 16+, Android 12+ |
| Auth & security | Firebase Auth + Firestore Security Rules (members only access their space) |
| Offline behaviour | Read-only (cached data visible, writes blocked with clear feedback) |
| Push notification delivery | ≤ 30 seconds after assignment |

---

## Future Versions

### MVP 2 — Multiple spaces & members
- Create multiple named spaces per user (e.g. Home, Work, Kids)
- Invite more than one partner per space
- Space switcher in navigation
- Dynamic member list in assignment UI

### MVP 3 — Power features
- Due dates and reminders
- Task comments and attachments
- Activity history / audit log
- Fair-share digest (AI weekly summary)

### MVP 4 — AI layer
- Natural language task creation
- Smart task suggestions
- Auto-categorize and prioritize tasks

---

## Next Steps

1. Architecture document — folder structure, repository pattern, Firestore security rules
2. Break PRD into GitHub Issues with labels and milestones
3. Flutter project scaffold ✅
4. Firebase project setup
