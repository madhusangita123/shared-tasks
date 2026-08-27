# shared-tasks
A real-time shared task app for households — couples and families — built with an AI-assisted Flutter workflow from PRD to PR

## Running Firebase emulators

Integration tests and manual testing against a local backend (instead of the live `shared-tasks-dev` project) use the Firebase Emulator Suite:

```bash
firebase emulators:start --only firestore,auth
```

`functions` is left out for now — there's no `functions/` code yet (Cloud Functions is MVP 1 build-order step 7), and including it fails to start with "No valid functions configuration detected." Add it back once that exists.

Or use the wrapper script, which pins the JDK version the emulators require (see `scripts/emulators.sh` for why):

```bash
./scripts/emulators.sh
```

Emulator UI: http://127.0.0.1:4000 · Auth: `127.0.0.1:9099` · Firestore: `127.0.0.1:8080`

Regular `flutter test` unit/widget tests do **not** need the emulators running — they mock Firebase via `mocktail`. The emulators are for integration tests (`test/helpers/firebase_test_helper.dart`), planned for MVP 2.
