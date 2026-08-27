# SharedTasks — Product Requirements Document
**Version:** MVP 2.0  
**Status:** Draft  
**Date:** August 2026  
**Stack:** Flutter · Firebase

---

## Problem Statement

Couples and households manage shared responsibilities — chores, errands, kids' activities — through a mix of WhatsApp messages, mental load, and verbal reminders. Tasks fall through the cracks. Nobody knows who's doing what right now. There is no single source of truth for "what needs doing" and "who's on it."

---

## Goal

Ship a focused mobile app for households where each person owns their task lists and can share any list with whoever's involved — a partner, a sibling, a kid, a housemate. Everyone on a shared list can add tasks, assign them, update status, and see each other's changes in real time — without refreshing, polling, or messaging.

---

## Scope

### In scope (MVP 1)
- Sign in with Google — no email/password, no account creation
- Home screen — all your spaces (private + shared) in one place
- Create multiple spaces — private by default
- Share any space via deep link — send via WhatsApp, iMessage, anywhere
- Recipient taps link → installs app → signs in → space appears in their home screen automatically
- Add, edit, delete tasks in any space
- Assign tasks to self or any space member
- Task status: To do → In progress → Done
- Live sync — all members see changes in real time
- Push notifications on any assignment

### Out of scope (MVP 1)
- Email / password sign in
- Apple sign-in
- Guest / anonymous mode
- Remove a member from a space
- Resharing by recipients
- Due dates and reminders
- Task comments or attachments
- AI suggestions
- Activity history / audit log
- Tablet / web support
- Offline mode

---

## User Stories & Acceptance Criteria

### US-01 — Sign in with Google
> "As a user, I want to sign in with my Google account so I can access my spaces without creating a new account."

- Sign-in screen shows app logo, tagline, and a single "Continue with Google" button.
- Tapping it triggers the native Google account picker — shows all Google accounts on device plus "Use another account".
- On success, display name, email, and avatar pulled from Google profile automatically — no manual entry.
- **First-time user** → lands on Home screen (empty state with prompt to create first space).
- **Returning user** → lands directly on Home screen with their spaces.
- Persistent session — app never asks to sign in again unless explicitly signed out.
- Sign out option available in app settings.
- **Error handling:**
  - User cancels Google picker → silent, return to sign-in screen, no error shown
  - Network error → inline: "No internet connection. Try again." with retry button
  - Any other failure → inline: "Sign in failed. Try again." with retry button
- ⚠ All errors shown inline — no modal dialogs.
- ⚠ No fallback to email/password or guest mode.

---

### US-02 — Home screen
> "As a user, I want to see all my spaces in one place so I know what I have going on."

- Home screen shows all spaces the user owns or is a member of.
- Each space card shows:
  - Space name
  - Number of open tasks
  - Member avatars (for shared spaces)
  - Visual indicator distinguishing private vs shared spaces
- Private spaces show no avatars — just the space name and task count.
- Shared spaces show avatars of all members.
- Empty state: friendly prompt to create first space.
- FAB or prominent button to create a new space.
- Spaces ordered by most recently updated.

---

### US-03 — Create a space
> "As a user, I want to create a named space so I can organise my tasks."

- Tapping "Create space" shows a simple input for the space name.
- Space name required, 3–40 characters.
- Creator is automatically set as owner and first member.
- New space is private by default — not shared with anyone.
- After creation, user lands on the (empty) task list for that space.

---

### US-04 — Share a space
> "As the owner, I want to share a space with anyone so we can collaborate on tasks."

- Space settings screen has a "Share" option.
- Tapping Share generates a unique deep link: `sharedtasks://join/{token}`
- Owner shares the link via native share sheet (WhatsApp, iMessage, etc.).
- **Recipient flow:**
  - **App installed** → tapping link opens app directly → space appears in recipient's home screen automatically → no accept screen needed.
  - **App not installed** → link fails to open → recipient installs app manually → owner resends link.
- Invite link expires after 1 year. Owner can regenerate at any time — old link immediately invalidated.
- Multiple people can join via the same link.
- Once joined, recipient's name and avatar appear in the space's member list.
- ⚠️ Deferred deep linking (app not installed → auto-join after install) is out of scope for MVP 1.
- ⚠️ A user joining a space they're already a member of → silent no-op, just navigate to that space.

---

### US-05 — Manage tasks
> "As any space member, I want to add, edit, and delete tasks so the list stays accurate."

- Add task: title required (max 120 chars), optional notes (max 500 chars).
- Edit: tap task → slide-up sheet with editable fields.
- Delete: swipe-to-delete with undo snackbar (5-second window).
- Any member can add, edit, delete any task in a shared space.
- Owner can add, edit, delete tasks in their private spaces.
- ⚠ Deleting a task that is "In progress" shows a confirmation prompt first.

---

### US-06 — Assign a task
> "As any member, I want to assign a task to myself or anyone in the space so ownership is clear."

- Tap task → assignment section shows all space members as tappable avatars.
- "Assign to me" is the first and most prominent option.
- Any member can be selected as assignee.
- Assigned member's avatar shown on the task card in list view.
- Task can be reassigned at any time.
- **Notifications on assignment:**
  - Assign to self → all other members notified: "[Name] is handling: [task title]"
  - Assign to someone else → that person notified: "[Name] assigned you: [task title]", all other members notified: "[Name] assigned [task title] to [assignee name]"
- ⚠ Unassigned tasks show a neutral "unassigned" state — not a warning.

---

### US-07 — Update task status
> "As any member, I want to mark a task in-progress or done so everyone knows where things stand."

- Status cycle: To do → In progress → Done. Done → To do is allowed (reopen).
- Status change accessible from both the task card (quick tap) and the detail sheet.
- Any member can change status on any task — not locked to assignee.
- Done tasks move to a collapsed "Completed" section at the bottom of the list.
- ⚠ Partner sees status change in under 2 seconds on a standard connection.

---

### US-08 — Live sync
> "As any member, I want to see everyone's changes without refreshing."

- All task mutations (add, edit, delete, assign, status change) propagate to all members in real time via Firestore listeners.
- New and changed task cards animate subtly when they update — no jarring full-list reload.
- Optimistic local update on mutation — UI reflects change before server confirms.
- ⚠ Conflict: last write wins. No merge UI in MVP 1.

---

### US-09 — Push notifications
> "As a member, I want to be notified on any assignment so I always know who's handling what."

- Notifications fire on assignment only — not on status changes, edits, or deletes.
- Assign to self → all other space members notified.
- Assign to another member → that member notified + all other members notified.
- Tapping notification deep-links directly to that task's detail sheet.
- Notification permission requested after user's first space is created or joined.
- ⚠ If permission denied, app functions normally — no repeated permission prompts.

---

## Task Status Model

```
todo  →  in_progress  →  done
done  →  todo  (reopen allowed)
```

Stored as `todo | in_progress | done` in Firestore.

---

## Data Model (Firestore)

### `users/{uid}`
| Field | Type | Notes |
|---|---|---|
| displayName | string | From Google profile |
| email | string | From Google profile |
| photoUrl | string? | From Google profile |
| fcmToken | string? | Updated on each sign-in |
| createdAt | timestamp | |

### `spaces/{spaceId}`
| Field | Type | Notes |
|---|---|---|
| name | string | 3–40 chars |
| ownerUid | string | Creator, always a member |
| memberUids | string[] | All members including owner |
| inviteToken | string | Current active token |
| inviteExpiresAt | timestamp | 1 year from generation |
| createdAt | timestamp | |

> Note: Users no longer have a `spaceId` field. To find all spaces for a user, query spaces where `memberUids` contains the user's uid.

### `spaces/{spaceId}/tasks/{taskId}`
| Field | Type | Notes |
|---|---|---|
| title | string | Max 120 chars |
| notes | string? | Max 500 chars |
| status | enum | todo \| in_progress \| done |
| assigneeUid | string? | Null if unassigned |
| createdBy | string | uid of creator |
| createdAt | timestamp | |
| updatedAt | timestamp | |

---

## Screens (MVP 1)

| ID | Name | Description |
|---|---|---|
| S-01 | Sign in | App logo, tagline, "Continue with Google" button only |
| S-02 | Home | All spaces — private and shared. FAB to create new space. |
| S-03 | Task list | Tasks for a single space, grouped by status. FAB to add task. |
| S-04 | Task detail | Slide-up sheet. Edit title, notes, assign, update status. |
| S-05 | Create space | Space name input. Created as private by default. |
| S-06 | Space settings | Space name, members list, Share button, regenerate link. |
| S-07 | Accept invite | Auto-resolved on deep link — no explicit screen needed. |

---

## Non-Functional Requirements

| Requirement | Target |
|---|---|
| Sync latency | ≤ 2 seconds (member sees task change on 4G) |
| App cold start | ≤ 2 seconds (open to home screen visible) |
| Platforms | iOS 16+, Android 12+ |
| Auth & security | Firebase Auth + Firestore Security Rules (members only access their spaces) |
| Offline behaviour | Read-only (cached data visible, writes blocked with clear feedback) |
| Push notification delivery | ≤ 30 seconds after assignment |

---

## Future Versions

### MVP 2 — Power collaboration
- Remove a member from a space
- Resharing by recipients
- Transfer space ownership

### MVP 3 — Power features
- Due dates and reminders
- Task comments and attachments
- Activity history / audit log
- Fair-share digest (who's doing what)

### MVP 4 — AI layer
- Natural language task creation
- Smart task suggestions
- Auto-categorize and prioritize tasks

---

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0 | April 2026 | Initial PRD — single shared space, two people |
| 1.1 | August 2026 | Replaced email/password with Google sign-in |
| 2.0 | August 2026 | Full redesign — multiple spaces per user, per-space sharing with anyone, home screen, invite link valid 1 year, notification model updated |