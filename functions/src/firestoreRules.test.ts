/**
 * Tests for `firestore.rules` (issue #12's `assignedByUidIsHonest()`
 * addition).
 *
 * These are the only rules in this project with dedicated tests — everything
 * else here is confidence that this one change doesn't regress legitimate
 * writes while it closes the spoofing gap it was added for. `flutter test`
 * never exercises real rules (every Dart test fakes the repository/
 * datasource layer, never hitting a real Firestore emulator), and
 * `onTaskAssigned.test.ts` uses the Admin SDK, which bypasses rules
 * entirely — so without this file, a rules regression would ship silently.
 *
 * Uses `@firebase/rules-unit-testing`, the canonical library for this —
 * unlike `firebase-admin`, it evaluates writes through the real rules
 * engine as a given `request.auth`, the same way the Flutter app's own
 * Firestore SDK calls do.
 *
 * Run via `npm test`, same as the rest of this project's Cloud Functions
 * tests — `firebase emulators:exec` starts the Firestore emulator first
 * (see functions/package.json), and this file reads `firestore.rules` off
 * disk into that emulator itself rather than relying on whatever the
 * emulator happened to load at startup, so it's always testing the current
 * file on disk.
 */

import {test, before, after, beforeEach} from "node:test";
import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {setLogLevel} from "firebase/firestore";

const SPACE_ID = "rules-space";
const OWNER_UID = "rules-owner-uid";
const MEMBER_UID = "rules-member-uid";
const OUTSIDER_UID = "rules-outsider-uid";

let testEnv: RulesTestEnvironment;

before(async () => {
  setLogLevel("error"); // Quiets the SDK's own noisy permission-denied logs.
  testEnv = await initializeTestEnvironment({
    projectId: "shared-tasks-dev",
    firestore: {
      host: "localhost",
      port: 8080,
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed the space doc with the Admin SDK context (bypasses rules — this
  // is setup, not the thing under test).
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection("spaces")
      .doc(SPACE_ID)
      .set({
        name: "Household",
        ownerUid: OWNER_UID,
        memberUids: [OWNER_UID, MEMBER_UID],
      });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test(
  "a member CAN assign a task to themselves (assignedByUid == their own uid)",
  async () => {
    const db = testEnv.authenticatedContext(MEMBER_UID).firestore();
    await assertSucceeds(
      db
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .set({
          title: "Buy milk",
          assigneeUid: MEMBER_UID,
          assignedByUid: MEMBER_UID,
        })
    );
  }
);

test(
  "a member CANNOT set assignedByUid to a different member's uid — the " +
    "exact spoof onTaskAssigned's own fix defends against, now closed at " +
    "the rules layer too",
  async () => {
    const db = testEnv.authenticatedContext(MEMBER_UID).firestore();
    await assertFails(
      db
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .set({
          title: "Buy milk",
          assigneeUid: MEMBER_UID,
          assignedByUid: OWNER_UID,
        })
    );
  }
);

test(
  "a member CAN unassign a task (assignedByUid: null) regardless of who " +
    "last assigned it",
  async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .set({
          title: "Buy milk",
          assigneeUid: OWNER_UID,
          assignedByUid: OWNER_UID,
        });
    });

    const db = testEnv.authenticatedContext(MEMBER_UID).firestore();
    await assertSucceeds(
      db
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .update({assigneeUid: null, assignedByUid: null})
    );
  }
);

test(
  "a member CAN edit a task's title without touching assignedByUid, even " +
    "though someone else assigned it — the exact scenario a naive " +
    "'assignedByUid must always equal the writer' rule would have broken",
  async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .set({
          title: "Buy milk",
          assigneeUid: OWNER_UID,
          assignedByUid: OWNER_UID,
        });
    });

    // MEMBER_UID (not the assigner) edits only the title.
    const db = testEnv.authenticatedContext(MEMBER_UID).firestore();
    await assertSucceeds(
      db
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .update({title: "Buy oat milk"})
    );
  }
);

test(
  "a non-member cannot write to the space's tasks at all (baseline " +
    "membership check still holds)",
  async () => {
    const db = testEnv.authenticatedContext(OUTSIDER_UID).firestore();
    await assertFails(
      db
        .collection("spaces")
        .doc(SPACE_ID)
        .collection("tasks")
        .doc("t1")
        .set({
          title: "Buy milk",
          assigneeUid: OUTSIDER_UID,
          assignedByUid: OUTSIDER_UID,
        })
    );
  }
);
