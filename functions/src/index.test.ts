/**
 * Test for the issue #27 scaffolding-proof function.
 *
 * Uses `firebase-functions-test` in offline mode (no project config, no
 * emulator required) to wrap and invoke the v2 callable directly. The
 * same `wrap()` call works unchanged if this is later pointed at a live
 * emulator by calling `firebaseFunctionsTest({ projectId: ... })`
 * instead of the zero-arg offline factory used here.
 *
 * Run via `npm test` (builds then runs with Node's built-in test runner).
 */

import {test, after} from "node:test";
import assert from "node:assert/strict";

import firebaseFunctionsTest from "firebase-functions-test";
import type {CallableRequest} from "firebase-functions/v2/https";

import {helloWorld} from "./index";

const testEnv = firebaseFunctionsTest();

test("helloWorld returns the expected greeting message", async () => {
  const wrapped = testEnv.wrap(helloWorld);
  const request = {data: undefined} as unknown as CallableRequest<undefined>;

  const result = await wrapped(request);

  assert.equal(result.message, "Hello from Cloud Functions!");
});

after(() => {
  testEnv.cleanup();
});
