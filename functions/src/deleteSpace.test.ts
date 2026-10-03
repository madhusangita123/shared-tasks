/**
 * Tests for `deleteSpace` (US-10, issue #64).
 *
 * Same harness and ordering constraints as `joinSpaceByToken.test.ts`:
 * `process.env.FIRESTORE_EMULATOR_HOST` is set *before* `./index` is
 * imported so `initializeApp()` picks up the emulator, and
 * `firebase-functions-test` is constructed in "online" mode with the
 * `.firebaserc` default project so `GCLOUD_PROJECT`/`FIREBASE_CONFIG`
 * match the emulator's project.
 *
 * Run via `npm test`, which starts the Firestore + Auth emulators with
 * `firebase emulators:exec` first — see functions/package.json.
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
import {deleteSpace} from "./index";
import {
  SPACES_COLLECTION,
  TASKS_COLLECTION,
  MEMBER_UIDS,
  OWNER_UID,
  INVITE_TOKEN,
  INVITE_EXPIRES_AT,
  UPDATED_AT,
  TITLE,
} from "./firestoreFields";

const firestore = getFirestore();
const wrapped = testEnv.wrap(deleteSpace);

const OWNER_TEST_UID = "test-owner-uid";
const MEMBER_TEST_UID = "test-member-uid";

const DOC_IDS = [
  "delete-owner",
  "delete-non-owner",
  "delete-with-tasks",
  "delete-over-batch-limit",
];

/**
 * Builds a fully-formed CallableRequest for a call to `deleteSpace`.
 * @param {string | undefined} spaceId - the space id to send as `data`.
 * @param {string | undefined} uid - the caller's uid, or `undefined` to
 *   simulate an unauthenticated call (no `auth` on the request).
 * @return {CallableRequest} a request usable with `testEnv.wrap(...)`.
 */
function authedRequest(
  spaceId: string | undefined,
  uid: string | undefined
): CallableRequest<{spaceId: string | undefined}> {
  const request = {
    data: {spaceId},
    auth:
      uid === undefined ?
        undefined :
        {
          uid,
          token: {uid} as unknown,
        },
  };
  return request as unknown as CallableRequest<{spaceId: string | undefined}>;
}

/**
 * Writes a `spaces/{docId}` doc directly via the Admin SDK, owned by
 * [OWNER_TEST_UID] with [MEMBER_TEST_UID] as a second member.
 * @param {string} docId - the document id to write under `spaces/`.
 * @return {Promise<void>} resolves once the doc has been written.
 */
async function seedSpace(docId: string): Promise<void> {
  await firestore
    .collection(SPACES_COLLECTION)
    .doc(docId)
    .set({
      name: "Test space",
      [OWNER_UID]: OWNER_TEST_UID,
      [MEMBER_UIDS]: [OWNER_TEST_UID, MEMBER_TEST_UID],
      [INVITE_TOKEN]: `token-${docId}`,
      [INVITE_EXPIRES_AT]: Timestamp.fromMillis(Date.now() + 1000),
      [UPDATED_AT]: Timestamp.fromMillis(0),
      createdAt: Timestamp.fromMillis(0),
    });
}

/**
 * Seeds `count` task docs under `spaces/{docId}/tasks`, in batches so a
 * count above Firestore's 500-op batch limit still writes.
 * @param {string} docId - the parent space's document id.
 * @param {number} count - how many task docs to create.
 * @return {Promise<void>} resolves once every task has been written.
 */
async function seedTasks(docId: string, count: number): Promise<void> {
  const tasksRef = firestore
    .collection(SPACES_COLLECTION)
    .doc(docId)
    .collection(TASKS_COLLECTION);

  for (let start = 0; start < count; start += 400) {
    const batch = firestore.batch();
    const end = Math.min(start + 400, count);
    for (let i = start; i < end; i++) {
      batch.set(tasksRef.doc(`task-${i}`), {
        [TITLE]: `Task ${i}`,
        status: "todo",
        createdBy: OWNER_TEST_UID,
        createdAt: Timestamp.fromMillis(0),
        [UPDATED_AT]: Timestamp.fromMillis(0),
      });
    }
    await batch.commit();
  }
}

/**
 * Deletes a space doc and every task under it, so a failed run can't
 * leave state behind for the next one.
 * @param {string} docId - the space document id to clear.
 * @return {Promise<void>} resolves once everything is gone.
 */
async function clearSpace(docId: string): Promise<void> {
  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(docId);
  for (;;) {
    const page = await spaceRef.collection(TASKS_COLLECTION).limit(400).get();
    if (page.empty) break;
    const batch = firestore.batch();
    for (const doc of page.docs) batch.delete(doc.ref);
    await batch.commit();
  }
  await spaceRef.delete();
}

before(async () => {
  // Sanity-check the emulator is actually reachable before running any
  // test — a clearer failure than a mysterious per-test timeout.
  await firestore.collection(SPACES_COLLECTION).limit(1).get();
});

beforeEach(async () => {
  await Promise.all(DOC_IDS.map(clearSpace));
});

after(async () => {
  await Promise.all(DOC_IDS.map(clearSpace));
  testEnv.cleanup();
});

test("owner can delete a space with no tasks", async () => {
  const docId = "delete-owner";
  await seedSpace(docId);

  const result = await wrapped(authedRequest(docId, OWNER_TEST_UID));
  assert.equal(result.deletedTaskCount, 0);

  const after1 = await firestore
    .collection(SPACES_COLLECTION)
    .doc(docId)
    .get();
  assert.equal(after1.exists, false);
});

test("deleting a space cascades to its tasks", async () => {
  const docId = "delete-with-tasks";
  await seedSpace(docId);
  await seedTasks(docId, 3);

  const result = await wrapped(authedRequest(docId, OWNER_TEST_UID));
  assert.equal(result.deletedTaskCount, 3);

  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(docId);
  assert.equal((await spaceRef.get()).exists, false);
  // The whole point of the function: no orphaned task documents survive
  // under a space that no rule can reach any more.
  const tasks = await spaceRef.collection(TASKS_COLLECTION).get();
  assert.equal(tasks.size, 0);
});

test("cascade handles more tasks than one WriteBatch allows", async () => {
  const docId = "delete-over-batch-limit";
  await seedSpace(docId);
  // 501 > the 500-op WriteBatch limit, so this only passes if the
  // delete loop actually pages instead of committing one batch.
  await seedTasks(docId, 501);

  const result = await wrapped(authedRequest(docId, OWNER_TEST_UID));
  assert.equal(result.deletedTaskCount, 501);

  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(docId);
  assert.equal((await spaceRef.get()).exists, false);
  const tasks = await spaceRef.collection(TASKS_COLLECTION).get();
  assert.equal(tasks.size, 0);
});

test("non-owner member throws permission-denied, space survives", async () => {
  const docId = "delete-non-owner";
  await seedSpace(docId);
  await seedTasks(docId, 2);

  await assert.rejects(
    () => wrapped(authedRequest(docId, MEMBER_TEST_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );

  // Rejected *before* any delete — neither the space nor its tasks moved.
  const spaceRef = firestore.collection(SPACES_COLLECTION).doc(docId);
  assert.equal((await spaceRef.get()).exists, true);
  const tasks = await spaceRef.collection(TASKS_COLLECTION).get();
  assert.equal(tasks.size, 2);
});

test("non-existent space throws failed-precondition, NOT not-found — "+
  "not-found is reserved for the callable itself being missing", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("no-such-space", OWNER_TEST_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

test("missing auth context throws unauthenticated", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("delete-owner", undefined)),
    (err: {code?: string}) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

test("missing spaceId throws invalid-argument", async () => {
  await assert.rejects(
    () => wrapped(authedRequest(undefined, OWNER_TEST_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("empty-string spaceId throws invalid-argument", async () => {
  await assert.rejects(
    () => wrapped(authedRequest("", OWNER_TEST_UID)),
    (err: {code?: string}) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});
