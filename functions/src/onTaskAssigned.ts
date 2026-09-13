/**
 * `onTaskAssigned` — push notification on task assignment (US-09, issue
 * #12).
 *
 * A 2nd-gen Firestore trigger, not a callable — it reacts to every write
 * under `spaces/{spaceId}/tasks/{taskId}` (`onDocumentWritten`, which fires
 * on create, update, *and* delete) and decides for itself whether that
 * write was actually an assignment:
 *
 *   - Fires only when `after.assigneeUid` is set AND differs from
 *     `before.assigneeUid` — covers both a brand-new task created with an
 *     assignee and a reassignment of an existing one.
 *   - Does NOT fire on unassign (`after.assigneeUid` becomes `null` — fails
 *     the "is set" half of the check above), on any other field-only edit
 *     (title/notes/status — `assigneeUid` unchanged), or on delete (`after`
 *     doesn't exist at all).
 *
 * `assignedByUid` (issue #9's `AssignTaskController`, this issue's addition
 * to the write) is what makes the notification copy possible at all — it's
 * how this function knows *who* performed the assignment, not just who was
 * assigned. Without it there's no name to put in "[Name] assigned you:
 * ...", so a write missing it is skipped rather than sent with a blank
 * name.
 *
 * Runs with the Admin SDK (via `initializeApp()` in `index.ts`), so it
 * bypasses `firestore.rules` entirely — appropriate here since it never
 * acts on anything an end user supplied directly, only on what already
 * landed in Firestore through the normal, rules-checked client write.
 *
 * A single bad FCM token (unregistered, uninstalled app, permission never
 * granted) must never fail the whole function — every send is best-effort,
 * logged and skipped on failure, per-token.
 */

import {getFirestore} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

import {
  ASSIGNED_BY_UID,
  ASSIGNEE_UID,
  DISPLAY_NAME,
  FCM_TOKEN,
  MEMBER_UIDS,
  NAME,
  SPACES_COLLECTION,
  TASKS_COLLECTION,
  TITLE,
  USERS_COLLECTION,
} from "./firestoreFields";

/**
 * Looks up `users/{uid}.displayName` for each of [uids], falling back to
 * [fallback] for any doc that's missing or has no name set.
 * @param {FirebaseFirestore.Firestore} firestore - the Admin SDK Firestore
 *   instance to read from.
 * @param {string[]} uids - the user ids to look up.
 * @param {string} fallback - the name to use when a doc has none.
 * @return {Promise<Map<string, string>>} uid -> display name.
 */
async function fetchDisplayNames(
  firestore: FirebaseFirestore.Firestore,
  uids: string[],
  fallback: string
): Promise<Map<string, string>> {
  const names = new Map<string, string>();
  const snapshots = await Promise.all(
    uids.map((uid) => firestore.collection(USERS_COLLECTION).doc(uid).get())
  );
  uids.forEach((uid, index) => {
    const displayName = snapshots[index].data()?.[DISPLAY_NAME] as
      | string
      | undefined;
    const hasName = displayName && displayName.length > 0;
    names.set(uid, hasName ? displayName : fallback);
  });
  return names;
}

/**
 * Sends one push notification (same title/body for everyone) to each of
 * [uids] whose `users/{uid}.fcmToken` is set. Missing tokens are skipped
 * silently — no token yet (permission never granted, or not signed in on
 * any device) is an expected, ordinary state, not an error. A per-token
 * send failure (e.g. `messaging/registration-token-not-registered`) is
 * logged and otherwise ignored — it must never fail the rest of the batch.
 * @param {FirebaseFirestore.Firestore} firestore - the Admin SDK Firestore
 *   instance to read `fcmToken`s from.
 * @param {string[]} uids - the recipient user ids.
 * @param {string} title - the notification title (the space name).
 * @param {string} body - the notification body (the assignment message).
 * @param {Record<string, string>} data - deep-link payload — all values
 *   must be strings per FCM's data-message requirement.
 * @return {Promise<void>} resolves once every send has been attempted.
 */
async function sendToUids(
  firestore: FirebaseFirestore.Firestore,
  uids: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  if (uids.length === 0) return;

  const snapshots = await Promise.all(
    uids.map((uid) => firestore.collection(USERS_COLLECTION).doc(uid).get())
  );
  const isNonEmptyToken = (token: string | undefined): token is string =>
    typeof token === "string" && token.length > 0;
  const tokens = snapshots
    .map((snapshot) => snapshot.data()?.[FCM_TOKEN] as string | undefined)
    .filter(isNonEmptyToken);

  if (tokens.length === 0) return;

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data,
    });
    response.responses.forEach((result, index) => {
      if (!result.success) {
        // Never log the raw token — it's a device/app-instance credential,
        // not diagnostic data. The index into this batch plus the error
        // itself is enough to debug a delivery failure without exposing
        // one.
        logger.warn(
          `onTaskAssigned: failed to send to recipient ${index} of ` +
            `${tokens.length}`,
          result.error
        );
      }
    });
  } catch (error) {
    // A whole-batch failure (e.g. Messaging unreachable) shouldn't throw
    // out of the trigger — the assignment write itself already succeeded
    // and must not be undone or retried because a notification failed.
    logger.error("onTaskAssigned: sendEachForMulticast failed", error);
  }
}

/**
 * Firestore trigger on `spaces/{spaceId}/tasks/{taskId}` — see the module
 * doc comment above for exactly when this fires.
 */
export const onTaskAssigned = onDocumentWritten(
  `${SPACES_COLLECTION}/{spaceId}/${TASKS_COLLECTION}/{taskId}`,
  async (event) => {
    const change = event.data;
    // No change payload at all, or the task was deleted — never notify.
    if (!change || !change.after.exists) return;

    const afterData = change.after.data();
    if (!afterData) return;

    const assigneeUid = afterData[ASSIGNEE_UID] as string | null | undefined;
    const previousAssigneeUid = change.before.exists ?
      (change.before.data()?.[ASSIGNEE_UID] as string | null | undefined) :
      undefined;

    // Only a genuine assignment (create-with-assignee or reassignment)
    // fires a notification — not an unassign (assigneeUid becomes null,
    // failing the truthy check below) and not any other field-only edit
    // (assigneeUid unchanged).
    if (!assigneeUid || assigneeUid === previousAssigneeUid) return;

    const assignedByUid = afterData[ASSIGNED_BY_UID] as string | undefined;
    // Without knowing who assigned it, there's no name for the copy — skip
    // rather than send a notification with a blank assigner.
    if (!assignedByUid) return;

    const taskTitle = (afterData[TITLE] as string | undefined) ?? "a task";
    const {spaceId, taskId} = event.params;

    const firestore = getFirestore();

    const spaceSnapshot = await firestore
      .collection(SPACES_COLLECTION)
      .doc(spaceId)
      .get();
    const spaceData = spaceSnapshot.data();
    if (!spaceData) return;

    const memberUids = Array.isArray(spaceData[MEMBER_UIDS]) ?
      (spaceData[MEMBER_UIDS] as string[]) :
      [];

    // `firestore.rules` only gates *that* a space member can write to this
    // task doc, not the *values* they write — a member could set
    // `assigneeUid`/`assignedByUid` to any uid via a direct Firestore call,
    // bypassing `AssignTaskController` entirely. Without this check, a
    // spoofed `assigneeUid` outside `memberUids` would leak the space name
    // and task title to an arbitrary uid's device (the "assign to someone
    // else" branch below sends straight to it), and a spoofed
    // `assignedByUid` would misattribute the notification's "[Name]" to
    // whoever that uid's `displayName` happens to be — including a real
    // person who was never actually involved. Requiring both to be
    // genuine current members closes both: every recipient this function
    // ever sends to is drawn from `memberUids` either way, so this is the
    // one gate that makes that guarantee actually hold against a
    // malicious write, not just an honest one.
    const assigneeIsMember = memberUids.includes(assigneeUid);
    const assignerIsMember = memberUids.includes(assignedByUid);
    if (!assigneeIsMember || !assignerIsMember) {
      logger.warn(
        "onTaskAssigned: assigneeUid or assignedByUid is not a current " +
          "space member — skipping (spoofed or stale write)",
        {spaceId, taskId}
      );
      return;
    }

    const spaceName = (spaceData[NAME] as string | undefined) ?? "SharedTasks";

    const namesToFetch = assigneeUid === assignedByUid ?
      [assignedByUid] :
      [assignedByUid, assigneeUid];
    const displayNames = await fetchDisplayNames(
      firestore,
      namesToFetch,
      "Someone"
    );
    const assignerName = displayNames.get(assignedByUid) ?? "Someone";

    const deepLinkData = {spaceId, taskId};

    if (assigneeUid === assignedByUid) {
      // Assigned to self — every other member is told who's handling it.
      const recipients = memberUids.filter((uid) => uid !== assignedByUid);
      await sendToUids(
        firestore,
        recipients,
        spaceName,
        `${assignerName} is handling: ${taskTitle}`,
        deepLinkData
      );
      return;
    }

    // Assigned to someone else — the assignee and everyone else each get
    // their own message text, so this is two separate send calls rather
    // than one broadcast.
    const assigneeName = displayNames.get(assigneeUid) ?? "Someone";

    await sendToUids(
      firestore,
      [assigneeUid],
      spaceName,
      `${assignerName} assigned you: ${taskTitle}`,
      deepLinkData
    );

    const otherRecipients = memberUids.filter(
      (uid) => uid !== assigneeUid && uid !== assignedByUid
    );
    await sendToUids(
      firestore,
      otherRecipients,
      spaceName,
      `${assignerName} assigned ${taskTitle} to ${assigneeName}`,
      deepLinkData
    );
  }
);
