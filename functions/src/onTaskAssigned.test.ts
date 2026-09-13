/**
 * Tests for `onTaskAssigned` (US-09, issue #12).
 *
 * Same emulator-backed setup as `joinSpaceByToken.test.ts` — `FIRESTORE_
 * EMULATOR_HOST` is set before `./index` is imported so `initializeApp()`
 * picks up the emulator, and `firebase-functions-test` runs in "online"
 * mode (a real `projectId`) so `GCLOUD_PROJECT` lines up with it.
 *
 * Unlike `joinSpaceByToken` (a callable, wrapped and invoked with a plain
 * `CallableRequest`), `onTaskAssigned` is a `onDocumentWritten` Firestore
 * trigger. `testEnv.wrap()` still works the same way, but the argument it
 * expects is a (partial) `CloudEvent` whose `data` is a `Change<
 * DocumentSnapshot>` — `firebase-functions-test` builds that snapshot pair
 * for us from plain before/after JSON objects passed as `data.before`/
 * `data.after` (see `firebase-functions-test/lib/cloudevent/mocks/
 * firestore/helpers.js`'s `getOrCreateDocumentSnapshotChange`), and fills
 * in the real `spaces/{spaceId}/tasks/{taskId}` path from the `params` we
 * supply, so no manual `DocumentSnapshot`/`Change` construction is needed
 * here.
 *
 * The Firestore emulator has no Messaging counterpart, so every real
 * `firebase-admin/messaging` call has to be stubbed rather than run for
 * real. `getMessaging()` returns one cached `Messaging` instance per Admin
 * SDK app — the same instance both this file and `onTaskAssigned.ts` get
 * back from their own `getMessaging()` calls (both resolve to the one app
 * `initializeApp()` set up in `index.ts`) — so mocking
 * `sendEachForMulticast` on it here, via `node:test`'s built-in
 * `mock.method`, intercepts every call the trigger makes.
 *
 * Run via `npm test`, which starts the Firestore + Auth emulators with
 * `firebase emulators:exec` before running this file — see
 * functions/package.json.
 */

import {test, before, after, beforeEach, mock} from "node:test";
import assert from "node:assert/strict";

process.env.FIRESTORE_EMULATOR_HOST = "localhost:8080";

import firebaseFunctionsTest from "firebase-functions-test";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import type {MulticastMessage, BatchResponse} from "firebase-admin/messaging";

const testEnv = firebaseFunctionsTest({projectId: "shared-tasks-dev"});

// Imported after the emulator env var + testEnv are set up, per the
// ordering note above.
import {onTaskAssigned} from "./index";
import {
  SPACES_COLLECTION,
  USERS_COLLECTION,
  MEMBER_UIDS,
  NAME,
  UPDATED_AT,
  DISPLAY_NAME,
  FCM_TOKEN,
  TITLE,
  ASSIGNEE_UID,
  ASSIGNED_BY_UID,
} from "./firestoreFields";

const firestore = getFirestore();
const wrapped = testEnv.wrap(onTaskAssigned);

const OWNER_UID = "test-owner-uid";
const OWNER_NAME = "Owner Olivia";
const MEMBER_B_UID = "test-member-b-uid";
const MEMBER_B_NAME = "Member Bob";
const MEMBER_C_UID = "test-member-c-uid";
const MEMBER_C_NAME = "Member Cara";

const SPACE_ID = "notif-space";
const TASK_ID = "notif-task";

/** Every uid this file's tests ever seed, for beforeEach/after cleanup. */
const SEEDED_UIDS = [OWNER_UID, MEMBER_B_UID, MEMBER_C_UID];

let sentMessages: MulticastMessage[] = [];

/**
 * Seeds `spaces/{SPACE_ID}` with [name] and [memberUids].
 * @param {string} name - the space's display name (the notification title).
 * @param {string[]} memberUids - the space's `memberUids`.
 * @return {Promise<void>} resolves once the doc is written.
 */
async function seedSpace(name: string, memberUids: string[]): Promise<void> {
  await firestore
    .collection(SPACES_COLLECTION)
    .doc(SPACE_ID)
    .set({
      [NAME]: name,
      ownerUid: memberUids[0],
      [MEMBER_UIDS]: memberUids,
      inviteToken: "irrelevant-token",
      inviteExpiresAt: Timestamp.fromMillis(Date.now() + 1000000),
      createdAt: Timestamp.fromMillis(0),
      [UPDATED_AT]: Timestamp.fromMillis(0),
    });
}

/**
 * Seeds `users/{uid}` with a display name and, optionally, an FCM token.
 * Omitting [fcmToken] simulates a user who never granted notification
 * permission (or has no token yet) — the "missing token" test case.
 * @param {string} uid - the user id to write.
 * @param {string} displayName - the user's `displayName`.
 * @param {string} [fcmToken] - the user's `fcmToken`, or omitted entirely.
 * @return {Promise<void>} resolves once the doc is written.
 */
async function seedUser(
  uid: string,
  displayName: string,
  fcmToken?: string
): Promise<void> {
  const data: Record<string, unknown> = {[DISPLAY_NAME]: displayName};
  if (fcmToken) data[FCM_TOKEN] = fcmToken;
  await firestore.collection(USERS_COLLECTION).doc(uid).set(data);
}

/**
 * Builds the `testEnv.wrap()` argument for a `spaces/{SPACE_ID}/tasks/
 * {TASK_ID}` write — see the module doc comment for how the plain
 * before/after JSON below becomes a real `Change<DocumentSnapshot>`.
 * @param {Record<string, unknown> | undefined} beforeData - the task's
 *   fields before the write, or `undefined` to simulate a create.
 * @param {Record<string, unknown> | undefined} afterData - the task's
 *   fields after the write, or `undefined` to simulate a delete.
 * @return {object} usable with `wrapped(...)`.
 */
function taskWrittenEvent(
  beforeData: Record<string, unknown> | undefined,
  afterData: Record<string, unknown> | undefined
): Parameters<typeof wrapped>[0] {
  const event = {
    params: {spaceId: SPACE_ID, taskId: TASK_ID},
    data: {before: beforeData, after: afterData},
  };
  return event as unknown as Parameters<typeof wrapped>[0];
}

before(async () => {
  // Sanity-check the emulator is actually reachable before running any
  // test — a clearer failure than a mysterious per-test timeout.
  await firestore.collection(SPACES_COLLECTION).limit(1).get();

  mock.method(
    getMessaging(),
    "sendEachForMulticast",
    async (message: MulticastMessage): Promise<BatchResponse> => {
      sentMessages.push(message);
      const tokens = message.tokens;
      return {
        responses: tokens.map(() => ({success: true})),
        successCount: tokens.length,
        failureCount: 0,
      };
    }
  );
});

beforeEach(async () => {
  sentMessages = [];
  await seedSpace("Household", [OWNER_UID, MEMBER_B_UID, MEMBER_C_UID]);
  await seedUser(OWNER_UID, OWNER_NAME, "token-owner");
  await seedUser(MEMBER_B_UID, MEMBER_B_NAME, "token-member-b");
  await seedUser(MEMBER_C_UID, MEMBER_C_NAME, "token-member-c");
});

after(async () => {
  await firestore.collection(SPACES_COLLECTION).doc(SPACE_ID).delete();
  await Promise.all(
    SEEDED_UIDS.map((uid) =>
      firestore.collection(USERS_COLLECTION).doc(uid).delete()
    )
  );
  mock.restoreAll();
  testEnv.cleanup();
});

test(
  "assigning to self notifies every other member, not the assigner",
  async () => {
    await wrapped(
      taskWrittenEvent(
        {
          [ASSIGNEE_UID]: null,
          [ASSIGNED_BY_UID]: null,
          [TITLE]: "Buy groceries",
        },
        {
          [ASSIGNEE_UID]: OWNER_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Buy groceries",
        }
      )
    );

    assert.equal(sentMessages.length, 1);
    const [message] = sentMessages;
    assert.deepEqual(
      [...message.tokens].sort(),
      ["token-member-b", "token-member-c"].sort()
    );
    assert.equal(message.notification?.title, "Household");
    assert.equal(
      message.notification?.body,
      `${OWNER_NAME} is handling: Buy groceries`
    );
    assert.deepEqual(message.data, {spaceId: SPACE_ID, taskId: TASK_ID});
  }
);

test(
  "assigning to another member notifies the assignee and other members " +
    "with different text, not the assigner",
  async () => {
    await wrapped(
      taskWrittenEvent(
        {
          [ASSIGNEE_UID]: null,
          [ASSIGNED_BY_UID]: null,
          [TITLE]: "Take out trash",
        },
        {
          [ASSIGNEE_UID]: MEMBER_B_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Take out trash",
        }
      )
    );

    assert.equal(sentMessages.length, 2);

    const assigneeMessage = sentMessages.find((message) =>
      message.tokens.includes("token-member-b")
    );
    assert.ok(assigneeMessage);
    assert.deepEqual(assigneeMessage.tokens, ["token-member-b"]);
    assert.equal(
      assigneeMessage.notification?.body,
      `${OWNER_NAME} assigned you: Take out trash`
    );

    const othersMessage = sentMessages.find((message) =>
      message.tokens.includes("token-member-c")
    );
    assert.ok(othersMessage);
    assert.deepEqual(othersMessage.tokens, ["token-member-c"]);
    assert.equal(
      othersMessage.notification?.body,
      `${OWNER_NAME} assigned Take out trash to ${MEMBER_B_NAME}`
    );

    // Neither message reaches the assigner themselves.
    assert.ok(
      sentMessages.every((message) => !message.tokens.includes("token-owner"))
    );
  }
);

test(
  "reassigning from one member to another (not from unassigned) " +
    "notifies the new assignee and other members, not the previous " +
    "assignee",
  async () => {
    await wrapped(
      taskWrittenEvent(
        {
          [ASSIGNEE_UID]: MEMBER_B_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Water the plants",
        },
        {
          [ASSIGNEE_UID]: MEMBER_C_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Water the plants",
        }
      )
    );

    assert.equal(sentMessages.length, 2);

    const assigneeMessage = sentMessages.find((message) =>
      message.tokens.includes("token-member-c")
    );
    assert.ok(assigneeMessage);
    assert.equal(
      assigneeMessage.notification?.body,
      `${OWNER_NAME} assigned you: Water the plants`
    );

    // The member who was assigned before this write (B) gets the "assigned
    // to" copy like any other non-assignee member, not the "assigned you"
    // copy meant for the *new* assignee — and the previous assignment
    // itself doesn't get a second notification of its own.
    const othersMessage = sentMessages.find((message) =>
      message.tokens.includes("token-member-b")
    );
    assert.ok(othersMessage);
    assert.equal(
      othersMessage.notification?.body,
      `${OWNER_NAME} assigned Water the plants to ${MEMBER_C_NAME}`
    );
  }
);

test(
  "a write with assigneeUid set but no assignedByUid does not send any " +
    "notification — there's no name for the copy",
  async () => {
    await wrapped(
      taskWrittenEvent(
        {
          [ASSIGNEE_UID]: null,
          [ASSIGNED_BY_UID]: null,
          [TITLE]: "Buy groceries",
        },
        {
          [ASSIGNEE_UID]: OWNER_UID,
          [TITLE]: "Buy groceries",
          // ASSIGNED_BY_UID deliberately omitted.
        }
      )
    );

    assert.equal(sentMessages.length, 0);
  }
);

test("unassigning a task does not send any notification", async () => {
  await wrapped(
    taskWrittenEvent(
      {
        [ASSIGNEE_UID]: MEMBER_B_UID,
        [ASSIGNED_BY_UID]: OWNER_UID,
        [TITLE]: "Water the plants",
      },
      {
        [ASSIGNEE_UID]: null,
        [ASSIGNED_BY_UID]: OWNER_UID,
        [TITLE]: "Water the plants",
      }
    )
  );

  assert.equal(sentMessages.length, 0);
});

test(
  "a field-only edit that doesn't change assigneeUid does not send any " +
    "notification",
  async () => {
    await wrapped(
      taskWrittenEvent(
        {
          [ASSIGNEE_UID]: MEMBER_B_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Water the plants",
          status: "todo",
        },
        {
          [ASSIGNEE_UID]: MEMBER_B_UID,
          [ASSIGNED_BY_UID]: OWNER_UID,
          [TITLE]: "Water the plants",
          status: "in_progress",
        }
      )
    );

    assert.equal(sentMessages.length, 0);
  }
);

test(
  "a recipient with no fcmToken yet is skipped without throwing",
  async () => {
    // Overwrite member B's seeded user doc with one that has no fcmToken
    // at all — simulates notification permission never having been
    // granted.
    await seedUser(MEMBER_B_UID, MEMBER_B_NAME);

    await assert.doesNotReject(() =>
      wrapped(
        taskWrittenEvent(
          {
            [ASSIGNEE_UID]: null,
            [ASSIGNED_BY_UID]: null,
            [TITLE]: "Buy groceries",
          },
          {
            [ASSIGNEE_UID]: OWNER_UID,
            [ASSIGNED_BY_UID]: OWNER_UID,
            [TITLE]: "Buy groceries",
          }
        )
      )
    );

    // Self-assign notifies every other member (B and C) — B has no token,
    // so only C's is actually present in the one message that goes out.
    assert.equal(sentMessages.length, 1);
    assert.deepEqual(sentMessages[0].tokens, ["token-member-c"]);
  }
);

test(
  "a spoofed assigneeUid outside the space's memberUids is skipped " +
    "without sending — a direct Firestore write can't leak a " +
    "notification to an arbitrary uid",
  async () => {
    const outsiderUid = "not-a-space-member-uid";
    // Seeded with a real fcmToken deliberately — without this, the test
    // would pass for the wrong reason (sendToUids already filters out any
    // uid with no token, membership check or not), proving nothing about
    // the membership check itself. With a real token present, the ONLY
    // thing that can still stop a send is the membership check.
    await seedUser(outsiderUid, "Outsider", "token-outsider");

    await assert.doesNotReject(() =>
      wrapped(
        taskWrittenEvent(
          {
            [ASSIGNEE_UID]: null,
            [ASSIGNED_BY_UID]: null,
            [TITLE]: "Buy groceries",
          },
          {
            [ASSIGNEE_UID]: outsiderUid,
            [ASSIGNED_BY_UID]: OWNER_UID,
            [TITLE]: "Buy groceries",
          }
        )
      )
    );

    assert.equal(sentMessages.length, 0);
  }
);

test(
  "a spoofed assignedByUid outside the space's memberUids is skipped " +
    "without sending — a direct Firestore write can't misattribute the " +
    "notification to an arbitrary uid",
  async () => {
    const outsiderUid = "not-a-space-member-uid";

    await assert.doesNotReject(() =>
      wrapped(
        taskWrittenEvent(
          {
            [ASSIGNEE_UID]: null,
            [ASSIGNED_BY_UID]: null,
            [TITLE]: "Buy groceries",
          },
          {
            [ASSIGNEE_UID]: MEMBER_B_UID,
            [ASSIGNED_BY_UID]: outsiderUid,
            [TITLE]: "Buy groceries",
          }
        )
      )
    );

    assert.equal(sentMessages.length, 0);
  }
);
