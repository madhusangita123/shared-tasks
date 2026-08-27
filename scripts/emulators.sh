#!/usr/bin/env bash
# Starts the Firebase emulators (Auth + Firestore) used for local dev/testing.
# Functions is intentionally excluded — no functions/ code exists yet
# (Cloud Functions is MVP 1 build-order step 7, not yet started). Add it
# back to the --only list below once functions/ has a real source config.
#
# firebase-tools requires JDK 21+, but this project's Android build is pinned
# to JDK 17 (see android/gradle.properties) for Gradle 8.12 compatibility.
# To avoid clashing with that pin, this script only overrides JAVA_HOME for
# the emulator process it launches — it does not touch your shell's default.
#
# Usage: ./scripts/emulators.sh [firebase emulators:start args...]
# Example: ./scripts/emulators.sh --import=./emulator-data --export-on-exit

set -euo pipefail

TEMURIN_21="/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home"

if [ -x "$TEMURIN_21/bin/java" ]; then
  export JAVA_HOME="$TEMURIN_21"
  export PATH="$JAVA_HOME/bin:$PATH"
elif command -v /usr/libexec/java_home >/dev/null 2>&1 && JH="$(/usr/libexec/java_home -v 21 2>/dev/null)"; then
  export JAVA_HOME="$JH"
  export PATH="$JAVA_HOME/bin:$PATH"
else
  echo "error: no JDK 21+ found." >&2
  echo "Install one, e.g.: brew install --cask temurin@21" >&2
  exit 1
fi

echo "Using JAVA_HOME=$JAVA_HOME ($(java -version 2>&1 | head -n1))"

exec firebase emulators:start --only auth,firestore "$@"
