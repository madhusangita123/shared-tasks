/**
 * Tests for `joinSpaceByToken` (US-04, issue #28).
 *
 * Unlike `index.test.ts` (which wraps `helloWorld` fully offline, no
 * project config or emulator needed), this function reads and writes real
 * Firestore documents, so it's tested against the Firestore emulator.
 *
 * `process.env.FIRESTORE_EMULATOR_HOST` is set below *before* `./index` is
 * imported, so that when `./index` calls `initializeApp()`, the Admin SDK
 * picks up the emulator instead of trying to reach a real project —
 * `joinSpaceByToken`'s own `getFirestore()` call happens lazily inside its
 * request handler, not at module load, but it still resolves to the same
 * (by-then emulator-configured) Admin SDK instance either way.
 * `firebase-functions-test` is constructed in "online" mode (a
 * `projectId` passed in, matching `.firebaserc`'s default project) so
 * `GCLOUD_PROJECT`/`FIREBASE_CONFIG` line up with the same project the
 * Firestore emulator is running as.
 *
 * Run via `npm test`, which starts the Firestore + Auth emulators with
 * `firebase emulators:exec` before running this file — see
 * functions/package.json.
 */

import {test, before, after, beforeEach} from "node:test";
import assert from "node:assert/strict";

process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";

import firebaseFunctionsTest from "firebase-functions-test";
import type {CallableRequest} from "firebase-functions/v2/https";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

const testEnv = firebaseFunctionsTest({projectId: "shared-tasks-dev"});

// Imported after the emulator env var + testEnv are set up, per the
// ordering note above.
import {joinSpaceByToken} from "./index";
import {
  SPACES_COLLECTION,
  MEMBER_UIDS,
  INVITE_TOKEN,
  INVITE_EXPIRES_AT,
  UPDATED_AT,
} from "./firestoreFields";

const firestore = getFirestore();
const wrapped = testEnv.wrap(joinSpaceByToken);

const CALLER_UID = "test-caller-uid";
const OTHER_MEMBER_UID = "test-other-member-uid";

/**
 * Builds a fully-formed CallableRequest for a call to `joinSpaceByToken`.
 * @param {string | undefined} token - the invite token to send as `data`.
 * @param {string | undefined} uid - the caller's uid, or `undefined` to
 *   simulate an unauthenticated call (no `auth` on the request).
 * @return {CallableRequest} a request usable with `testEnv.wrap(...)`.
 */
function authedRequest(
  token: string | undefined,
  uid: string | undefined
): CallableRequest<{token: string | undefined}> {
  const request = {
    data: {token},
    auth:
      uid === undefined ?
        undefined :
        {
          uid,
          token: {uid} as unknown,
        },
  };
  return request as unknown as CallableRequest<{token: string | undefined}>;
}

/**
 * Writes a `spaces/{docId}` doc directly via the Admin SDK.
 * @param {string} docId - the document id to write under `spaces/`.
 * @param {object} fields - the invite/member fields to seed the doc with.
 * @return {Promise<void>} resolves once the doc has been written.
 */
async function seedSpace(
  docId: string,
  fields: {
    inviteToken: string;
    inviteExpiresAt: Timestamp;
    memberUids: string[];
  }
): Promise<void> {
  await firestore
    .collection(SPACES_COLLECTION)
    .doc(docId)
    .set({
      name: "Test space",
      ownerUid: OTHER_MEMBER_UID,
      [INVITE_TOKEN]: fields.inviteToken,
      [INVITE_EXPIRES_AT]: fields.inviteExpiresAt,
      [MEMBER_UIDS]: fields.memberUids,
      [UPDATED_AT]: Timestamp.fromMillis(0),
      createdAt: Timestamp.fromMillis(0),
    });
}

/**
 * @return {Timestamp} one year from now — a non-expired invite.
 */
function futureTimestamp(): Timestamp {
  return Timestamp.fromMillis(Date.now() + 365 * 24 * 60 * 60 * 1000);
}

/**
 * @return {Timestamp} one hour ago — an already-expired invite.
 */
function pastTimestamp(): Timestamp {
  return Timestamp.fromMillis(Date.now() - 60 * 60 * 1000);
}

before(async () => {
  // Sanity-check the emulator is actually reachable before running any
  // test — a clearer failure than a mysterious per-test timeout.
  await firestore.collection(SPACES_COLLECTION).limit(1).get();
});

beforeEach(async () => {
  // Each test uses its own doc id, but belt-and-suspenders: make sure no
  // stale docs from a previous failed run linger under these ids.
  const ids = [
    "join-valid",
    "join-expired",
    "join-already-member",
  ];
  await Promise.all(
    ids.map((id) => firestore.collection(SPACES_COLLECTION).doc(id).delete())
  );
});

after(async () => {
  const ids = [
    "join-valid",
    "join-expired",
    "join-already-member",
  ];
  await Promise.all(
    ids.map((id) => firestore.collection(SPACES_COLLECTION).doc(id).delete())
  );
  testEnv.cleanup();
});

test("valid, non-expired token adds the caller to memberUids", async () => {
  const docId = "join-valid";
  await seedSpace(docId, {
    inviteToken: "valid-token",
    inviteExpiresAt: futureTimestamp(),
    memberUids: [OTHER_MEMBER_UID],
  });

  const result = await wrapped(authedRequest("valid-token", CALLER_UID));

  assert.equal(result.spaceId, docId);

  const after1 = await firestore.collection(SPACES_COLLECTION).doc(docId).get();
  const data = after1.data();
  assert.ok(data);
  assert.deepEqual(
    [...data[MEMBER_UIDS]].sort(),
    [CALLER_UID, OTHER_MEMBER_UID].sort()
  );
  assert.ok(
    (data[UPDATED_AT] as Timestamp).toMillis() >
      Timestamp.fromMillis(0).toMillis(),
    "updatedAt should have been bumped by serverTimestamp()"
  );
});

test("expired token throws failed-precondition", async () => {
  const docId = "join-expired";
  await seedSpace(docId, {
    inviteToken: "expired-token",
    inviteExpiresAt: pastTimestamp(),
    memberUids: [OTHER_MEMBER_UID],
  });

  await assert.rejects(
    () => wrapped(authedRequest("expired-token", CALLER_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

test("non-existent token throws not-found", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("no-such-token", CALLER_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});

test("already-a-member is a silent no-op returning spaceId", async () => {
  const docId = "join-already-member";
  await seedSpace(docId, {
    inviteToken: "already-member-token",
    inviteExpiresAt: futureTimestamp(),
    memberUids: [OTHER_MEMBER_UID, CALLER_UID],
  });

  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(docId);
  const before1 = await spaceRef.get();
  const beforeData = before1.data();
  assert.ok(beforeData);
  const beforeMemberCount = (beforeData[MEMBER_UIDS] as string[]).length;
  const beforeUpdatedAtMillis =
    (beforeData[UPDATED_AT] as Timestamp).toMillis();

  const request = authedRequest("already-member-token", CALLER_UID);
  const result = await wrapped(request);

  assert.equal(result.spaceId, docId);

  const after1 = await spaceRef.get();
  const afterData = after1.data();
  assert.ok(afterData);
  // Proves this was a true no-op, not a duplicate-tolerant arrayUnion
  // write: memberUids length is unchanged (no duplicate uid added) and
  // updatedAt was never touched (no `.update()` call was made at all).
  assert.equal(
    (afterData[MEMBER_UIDS] as string[]).length,
    beforeMemberCount
  );
  assert.equal(
    (afterData[UPDATED_AT] as Timestamp).toMillis(),
    beforeUpdatedAtMillis
  );
});

test("missing auth context throws unauthenticated", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("irrelevant-token", undefined)),
    (err: {code?: string}) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

test("missing token throws invalid-argument", async () => {
  await assert.rejects(
    () => wrapped(authedRequest(undefined, CALLER_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("empty-string token throws invalid-argument", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("", CALLER_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});
