# Firebase Setup Guide

## Overview

This is a one-time manual setup. Firebase console does not have a full API so this cannot be automated. Follow every step in order — skipping steps will cause runtime crashes.

Estimated time: **45-60 minutes**

---

## Prerequisites

- Google account (personal — not work)
- Flutter project cloned and running locally
- Node.js 18+ installed (for Firebase CLI)
- Xcode installed (for iOS setup)
- Android Studio installed (for Android setup)

---

## Step 1 — Install Firebase CLI

```bash
npm install -g firebase-tools
firebase --version  # should show 13.x or higher
firebase login      # sign in with your Google account
```

---

## Step 2 — Create Firebase Projects

You need **two** Firebase projects:
- `shared-tasks-dev` — for day-to-day development
- `shared-tasks-prod` — for production (create now, configure later)

### Create shared-tasks-dev

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click **"Add project"**
3. Name: `shared-tasks-dev`
4. Disable Google Analytics (not needed for MVP 1)
5. Click **"Create project"**

Repeat for `shared-tasks-prod`.

---

## Step 3 — Enable Firebase Services

Do this for **both** projects.

### Firebase Authentication
1. Firebase console → your project → **Authentication**
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Enable **Google** provider
5. Set project support email (your email)
6. Save

### Firestore Database
1. Firebase console → **Firestore Database**
2. Click **"Create database"**
3. Select **"Start in production mode"** (we add rules in Step 7)
4. Choose region closest to you (e.g. `asia-south1` for India)
5. Click **"Enable"**

### Firebase Cloud Messaging
1. Firebase console → **Project settings** → **Cloud Messaging**
2. FCM is enabled by default — no action needed
3. Note your **Server key** for later

---

## Step 4 — Add Flutter Apps to Firebase

### Android app

1. Firebase console → Project overview → **"Add app"** → Android icon
2. Android package name: `com.madhusangita.shared_tasks`
3. App nickname: `SharedTasks Android`
4. **SHA-1 certificate** — run this in terminal:

```bash
cd android
./gradlew signingReport
```

Copy the SHA-1 from the `debug` variant and paste it in Firebase.

5. Click **"Register app"**
6. Download `google-services.json`
7. Place it at: `android/app/google-services.json`

### iOS app

1. Firebase console → **"Add app"** → iOS icon
2. iOS bundle ID: `com.madhusangita.sharedTasks`
3. App nickname: `SharedTasks iOS`
4. Click **"Register app"**
5. Download `GoogleService-Info.plist`
6. Open Xcode: `open ios/Runner.xcworkspace`
7. Drag `GoogleService-Info.plist` into the `Runner` folder in Xcode
8. Make sure **"Copy items if needed"** is checked
9. Click **"Finish"**

---

## Step 5 — Configure Flutter Project

### Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

### Run FlutterFire configure

```bash
cd ~/Projects/shared-tasks
flutterfire configure --project=shared-tasks-dev
```

This generates `lib/firebase_options.dart` automatically.

### Update pubspec.yaml

Verify these are in your `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  firebase_messaging: ^15.0.0
  google_sign_in: ^6.2.1
  app_links: ^6.0.0
```

Run:

```bash
flutter pub get
```

---

## Step 6 — Configure Google Sign-In

### Android — add OAuth client

Google Sign-In on Android requires the SHA-1 you added in Step 4.
Firebase auto-creates the OAuth client — verify at:

[console.cloud.google.com](https://console.cloud.google.com) → APIs & Services → Credentials

You should see an Android OAuth client for your package name.

### iOS — add URL scheme

1. Open `GoogleService-Info.plist`
2. Find the value for `REVERSED_CLIENT_ID`
3. Open Xcode → Runner → Info → URL Types
4. Click **+** and add:
   - URL Schemes: paste the `REVERSED_CLIENT_ID` value

### app_links — deep link setup

**Android** — add to `android/app/src/main/AndroidManifest.xml` inside `<activity>`:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="sharedtasks" android:host="join" />
</intent-filter>
```

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sharedtasks</string>
    </array>
  </dict>
</array>
```

---

## Step 7 — Deploy Firestore Security Rules

Create `firestore.rules` at the project root:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    match /spaces/{spaceId} {
      allow read: if request.auth.uid in resource.data.memberUids;
      allow create: if request.auth.uid == request.resource.data.ownerUid
                    && request.auth.uid in request.resource.data.memberUids;
      allow update: if request.auth.uid in resource.data.memberUids;
      allow delete: if request.auth.uid == resource.data.ownerUid;

      match /tasks/{taskId} {
        allow read, write: if request.auth.uid in
          get(/databases/$(database)/documents/spaces/$(spaceId)).data.memberUids;
      }
    }
  }
}
```

Create `firebase.json` at the project root:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080
    },
    "functions": {
      "port": 5001
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

Deploy rules to dev project:

```bash
firebase use shared-tasks-dev
firebase deploy --only firestore:rules
```

---

## Step 8 — Set Up Firebase Emulator

```bash
firebase init emulators
```

Select:
- ✅ Authentication Emulator
- ✅ Firestore Emulator
- ✅ Functions Emulator

Accept default ports.

### Verify emulator runs

```bash
firebase emulators:start --only firestore,auth
```

You should see the emulator UI at `http://localhost:4000`

---

## Step 9 — Update .gitignore

Make sure these are in your `.gitignore`:

```
# Firebase config — never commit
google-services.json
**/GoogleService-Info.plist
lib/firebase_options.dart
.env
.firebaserc
```

---

## Step 10 — Verify Everything Works

```bash
flutter clean
flutter pub get
flutter run
```

On first launch you should see the sign-in screen with "Continue with Google".

Test Google Sign-In — if it works, Firebase is correctly configured.

---

## Troubleshooting

**`google-services.json` not found**
Make sure it's at `android/app/google-services.json` — not `android/google-services.json`.

**Google Sign-In fails on Android**
SHA-1 mismatch. Run `./gradlew signingReport` again and verify the SHA-1 in Firebase console matches.

**Google Sign-In fails on iOS**
`REVERSED_CLIENT_ID` URL scheme missing. Check Step 6 iOS section.

**Firestore permission denied**
Security rules not deployed. Run `firebase deploy --only firestore:rules`.

**Emulator not connecting**
Check `test/helpers/firebase_test_helper.dart` — emulator host must be `localhost` not `127.0.0.1` on some machines.

---

## After Setup

Once Firebase is configured:

1. Update `CLAUDE.md` current status — mark Firebase setup complete
2. Close GitHub issue #1 `[CHORE] Firebase project setup`
3. Run the orchestrator for the first feature:

```bash
cd ~/Projects/shared-tasks
python scripts/orchestrator.py --issue 2
```

---

## Environment Variables

Create `.env` at project root (gitignored):

```
ANTHROPIC_API_KEY=your_key_here
GITHUB_TOKEN=your_token_here
FIREBASE_PROJECT_ID=shared-tasks-dev
```

The orchestrator reads these via `python-dotenv`.
