/**
 * `deleteSpace` — owner-only, cascading deletion of a space and every task
 * under it (US-10, issue #64).
 *
 * Why this has to run server-side, with the Admin SDK, instead of as a
 * client-side batched delete:
 *
 *   - Firestore does not cascade. Deleting `spaces/{spaceId}` leaves
 *     `spaces/{spaceId}/tasks/*` behind as orphans: still stored, still
 *     billed, and permanently unreachable, because `firestore.rules` gates
 *     task access on a `get()` of the parent space document that no longer
 *     exists. The tasks therefore have to go first, and that multi-step
 *     sequence must not depend on the client surviving to the end of it.
 *   - A half-finished delete is visible to the *other* members of the
 *     space, not just to whoever tapped the button. Running here means the
 *     sequence completes even if the app is killed or loses connectivity
 *     the moment the call is dispatched.
 *
 * Note that the Admin SDK bypasses `firestore.rules` entirely — including
 * `allow delete: if request.auth.uid == resource.data.ownerUid` on
 * `spaces/{spaceId}`. The `ownerUid === request.auth.uid` check below IS
 * the enforcement of owner-only deletion for this path; there is no rule
 * underneath it that would catch a non-owner if that check were removed.
 * `firestore.rules` is deliberately left untouched by this issue.
 */

import {getFirestore} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";

import {
  SPACES_COLLECTION,
  TASKS_COLLECTION,
  OWNER_UID,
} from "./firestoreFields";

interface DeleteSpaceData {
  spaceId: string;
}

/**
 * Firestore's hard limit on writes in a single `WriteBatch`. The task
 * subcollection is deleted in pages of this size.
 */
const BATCH_LIMIT = 500;

/**
 * Callable: `deleteSpace({ spaceId })`.
 *
 * - Requires an authenticated caller (`request.auth`), who must be the
 *   space's `ownerUid` — see the module comment for why that check lives
 *   here and not in `firestore.rules`.
 * - Rejects with `failed-precondition` if the space doesn't exist, so a
 *   double-tap
 *   (or a retry after a delete that already succeeded) reports honestly
 *   rather than silently "succeeding" on nothing.
 * - Deletes every doc under `spaces/{spaceId}/tasks` in batches of
 *   [BATCH_LIMIT], then deletes the space document **last**. The ordering
 *   matters: an interrupted run leaves a space whose delete can simply be
 *   retried, rather than orphaned tasks that no rule can ever reach again.
 */
export const deleteSpace = onCall<DeleteSpaceData>(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "You must be signed in to delete a space."
    );
  }

  const spaceId = request.data?.spaceId;
  if (typeof spaceId !== "string" || spaceId.length === 0) {
    throw new HttpsError("invalid-argument", "A spaceId is required.");
  }

  const uid = request.auth.uid;

  const firestore = getFirestore();
  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(spaceId);
  const snapshot = await spaceRef.get();

  if (!snapshot.exists) {
    // `failed-precondition`, deliberately NOT `not-found`. The Functions
    // transport layer itself returns NOT_FOUND when the callable doesn't
    // exist at all — not deployed, renamed, or deployed to a different
    // region. A client cannot tell that apart from a NOT_FOUND thrown
    // here, so using `not-found` for a missing space made the app report
    // "This space no longer exists." about a space sitting right there on
    // screen whenever the backend was simply unreachable. Caught on an
    // emulator against an undeployed function; the whole test suite
    // passed throughout. Keep these two codes distinct.
    throw new HttpsError("failed-precondition", "This space no longer exists.");
  }

  const ownerUid = snapshot.data()?.[OWNER_UID] as string | undefined;
  if (ownerUid !== uid) {
    throw new HttpsError(
      "permission-denied",
      "Only the owner can delete this space."
    );
  }

  const tasksRef = spaceRef.collection(TASKS_COLLECTION);
  let deletedTaskCount = 0;

  // Loop until a page comes back empty rather than paging by cursor: the
  // docs just read are deleted before the next query runs, so the "first
  // BATCH_LIMIT docs" window always advances on its own.
  for (;;) {
    const page = await tasksRef.limit(BATCH_LIMIT).get();
    if (page.empty) break;

    const batch = firestore.batch();
    for (const doc of page.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deletedTaskCount += page.size;
  }

  // Last, deliberately — see the doc comment above.
  await spaceRef.delete();

  return {deletedTaskCount};
});
