/**
 * Cloud Functions entry point for SharedTasks.
 *
 * `helloWorld` below is a scaffolding-proof function for issue #27
 * (Cloud Functions project setup). It exists only to prove that the
 * init -> build -> deploy pipeline works end-to-end against the dev
 * project.
 *
 * `joinSpaceByToken` is the first real, trusted server-side function this
 * setup unblocks — it validates and applies the invite-accept flow
 * (US-04, issue #28). It will be joined by the task-assignment push
 * notification trigger (#12).
 */

import {initializeApp} from "firebase-admin/app";
import {onCall} from "firebase-functions/v2/https";

// Initialize the Admin SDK once per Cloud Functions instance. Modules
// imported below (e.g. `./joinSpaceByToken`) call `getFirestore()` lazily,
// inside their request handlers — not at module load time — so the only
// real requirement is that this runs before any handler is ever invoked,
// which it always is (Cloud Functions runs this module top-to-bottom once
// per instance, before routing any request to a handler).
initializeApp();

export {joinSpaceByToken} from "./joinSpaceByToken";

/**
 * Trivial callable used to prove the Cloud Functions deploy pipeline
 * (build -> emulate/deploy -> invoke) works end-to-end. See issue #27.
 */
export const helloWorld = onCall((request) => {
  return {message: "Hello from Cloud Functions!"};
});
