# SharedTasks Cloud Functions

Trusted server-side logic for SharedTasks — invite token validation, push
notifications on task assignment. Separate Node/TypeScript project from the
Flutter app; none of the Flutter conventions apply here.

See `docs/ARCHITECTURE.md`'s "Cloud Functions" section for full setup,
local emulator, testing, and deploy instructions.

## ⚠️ Node.js 20 runtime deadline — 2026-10-30

`engines.node` is pinned to `"20"` in `package.json`, deliberately — see the
explanation in `docs/ARCHITECTURE.md`. Node 20 was deprecated by
Google Cloud Functions on 2026-04-30 and will be **decommissioned on
2026-10-30**. Deploys will fail after that date until the runtime is
upgraded (which also means re-resolving the `firebase-admin` /
`typescript` / `@typescript-eslint` version constraints, currently coupled
to Node 20 — see `package.json`). Don't let this slip past the deadline.
