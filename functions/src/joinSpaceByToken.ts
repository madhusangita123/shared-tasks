/**
 * `joinSpaceByToken` — server-side validation for the invite-accept flow
 * (US-04, issue #28).
 *
 * Why this has to run server-side, with the Admin SDK, instead of as a
 * plain client write:
 *
 *   - The client can't safely look up a space by its invite token under
 *     the existing `firestore.rules`: reading `spaces/{spaceId}` requires
 *     `request.auth.uid in resource.data.memberUids` (see firestore.rules),
 *     i.e. you already have to be a member to read the space you're trying
 *     to join. A client-side "query spaces where inviteToken == token"
 *     would be rejected before the recipient ever gets to see the space.
 *   - Even if reads were opened up, the client still can't be trusted to
 *     add itself (or, if compromised/tampered with, some other uid) to
 *     `memberUids` correctly — token expiry has to be checked against the
 *     server's clock, and the uid being added has to be exactly the
 *     caller's authenticated uid, never a client-supplied value.
 *
 * This function uses the Admin SDK, which bypasses `firestore.rules`
 * entirely — that's the whole point: it does the membership check itself,
 * using `request.auth.uid` from the verified ID token, never anything the
 * client puts in the request body. `firestore.rules` is deliberately left
 * untouched by this issue.
 */

import {getFirestore, FieldValue, Timestamp} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";

import {
  SPACES_COLLECTION,
  MEMBER_UIDS,
  INVITE_TOKEN,
  INVITE_EXPIRES_AT,
  UPDATED_AT,
} from "./firestoreFields";

interface JoinSpaceByTokenData {
  token: string;
}

/**
 * Callable: `joinSpaceByToken({ token })`.
 *
 * - Requires an authenticated caller (`request.auth`); the uid added to the
 *   space is always `request.auth.uid`, never anything from `request.data`.
 * - Looks up the space whose `inviteToken` matches, via the Admin SDK.
 * - Rejects with `not-found` if no space matches, or `failed-precondition`
 *   if the invite has expired.
 * - If the caller is already a member, this is a silent no-op that still
 *   returns `{ spaceId }` — joining twice (e.g. tapping the link again)
 *   must not error or duplicate the uid in `memberUids`.
 * - Otherwise adds the caller's uid via `arrayUnion` and bumps `updatedAt`.
 */
export const joinSpaceByToken = onCall<JoinSpaceByTokenData>(
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to join a space."
      );
    }

    const token = request.data?.token;
    if (typeof token !== "string" || token.length === 0) {
      throw new HttpsError("invalid-argument", "A token is required.");
    }

    const uid = request.auth.uid;

    const firestore = getFirestore();
    const snapshot = await firestore
      .collection(SPACES_COLLECTION)
      .where(INVITE_TOKEN, "==", token)
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new HttpsError("not-found", "This invite link is invalid.");
    }

    const doc = snapshot.docs[0];
    const data = doc.data();

    const inviteExpiresAt = data[INVITE_EXPIRES_AT] as Timestamp | undefined;
    if (!inviteExpiresAt || inviteExpiresAt.toMillis() < Date.now()) {
      throw new HttpsError(
        "failed-precondition",
        "This invite link has expired."
      );
    }

    const memberUids: unknown = data[MEMBER_UIDS];
    const currentMemberUids = Array.isArray(memberUids) ? memberUids : [];

    if (currentMemberUids.includes(uid)) {
      // Already a member — silent no-op, no write.
      return {spaceId: doc.id};
    }

    await doc.ref.update({
      [MEMBER_UIDS]: FieldValue.arrayUnion(uid),
      [UPDATED_AT]: FieldValue.serverTimestamp(),
    });

    return {spaceId: doc.id};
  }
);
