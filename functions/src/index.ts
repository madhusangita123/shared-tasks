/**
 * Cloud Functions entry point for SharedTasks.
 *
 * `helloWorld` below is a scaffolding-proof function for issue #27
 * (Cloud Functions project setup). It exists only to prove that the
 * init -> build -> deploy pipeline works end-to-end against the dev
 * project. It will be joined by the real, trusted server-side functions
 * this setup unblocks: `joinSpaceByToken` (invite accept flow, #7/#28)
 * and the task-assignment push notification trigger (#12).
 */

import {initializeApp} from "firebase-admin/app";
import {onCall} from "firebase-functions/v2/https";

// Initialize the Admin SDK once per Cloud Functions instance.
initializeApp();

/**
 * Trivial callable used to prove the Cloud Functions deploy pipeline
 * (build -> emulate/deploy -> invoke) works end-to-end. See issue #27.
 */
export const helloWorld = onCall((request) => {
  return {message: "Hello from Cloud Functions!"};
});
