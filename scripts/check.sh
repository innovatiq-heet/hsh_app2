#!/usr/bin/env bash
# Runs the automated checks for HSH App, and optionally the hsh_api backend.
# CI (.github/workflows/ci.yml) runs the same steps.
#
# Usage (from any directory; works in Git Bash on Windows):
#   bash scripts/check.sh                      analyze + offline tests
#   bash scripts/check.sh --android            + compile the native Android code (Kotlin)
#   bash scripts/check.sh --api ../hsh_api     + backend: typecheck, JS-mirror check, e2e tests
#                                              (needs MySQL on localhost and hsh_api/.env)
#   bash scripts/check.sh --android --api ../hsh_api   everything
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID=0
API_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android) ANDROID=1 ;;
    --api)
      API_DIR="${2:-}"
      [[ -n "$API_DIR" ]] || { echo "--api needs the path to the hsh_api checkout" >&2; exit 2; }
      shift
      ;;
    -h | --help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown option: $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

step() { printf '\n==> %s\n' "$*"; }

cd "$ROOT"

step "flutter pub get"
if [[ -n "${CI:-}" ]]; then
  # CI must test exactly the committed package versions.
  flutter pub get --enforce-lockfile
else
  flutter pub get
  if command -v git >/dev/null && ! git -C "$ROOT" diff --quiet -- pubspec.lock 2>/dev/null; then
    echo "WARNING: pubspec.lock now differs from git. If you didn't change dependencies, your" >&2
    echo "         Flutter is older than the lockfile needs (Flutter >= 3.44): run 'flutter upgrade'," >&2
    echo "         and don't commit this pubspec.lock change ('git checkout -- pubspec.lock' undoes it)." >&2
  fi
fi

step "flutter analyze"
flutter analyze

step "flutter test (offline; tests tagged 'live' call real APIs and are skipped)"
flutter test --exclude-tags live

if [[ $ANDROID -eq 1 ]]; then
  step "Compile native Android code (Kotlin)"
  (cd android && ./gradlew :app:compileDebugKotlin --console=plain)
fi

if [[ -n "$API_DIR" ]]; then
  [[ -f "$API_DIR/package.json" ]] || { echo "No hsh_api checkout at $API_DIR" >&2; exit 2; }
  step "Backend checks in $API_DIR (typecheck, JS mirrors, e2e)"
  (
    cd "$API_DIR"
    [[ -d node_modules ]] || npm ci
    npm run check
  )
fi

step "All checks passed."
