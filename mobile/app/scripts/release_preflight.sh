#!/usr/bin/env bash
set -euo pipefail

# Yala Flood Watch — iOS Pre-Flight Verification & Release IPA Builder
# Usage:
#   ./scripts/release_preflight.sh                                       # Pre-flight checks only
#   ./scripts/release_preflight.sh "https://<proj>.supabase.co/storage/v1/object/public/snapshots"  # Build signed IPA

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${APP_DIR}/../.." && pwd)"
CDN_BASE="${1:-}"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/tokyo/flutter-sdk/bin/flutter}"

if ! command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
fi

echo "==> [1/6] Checking Apple App Store Mandatory Files..."
test -f "${APP_DIR}/ios/Runner/Info.plist"
test -f "${APP_DIR}/ios/Runner/PrivacyInfo.xcprivacy"
test -f "${APP_DIR}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
if grep -q "ITSAppUsesNonExemptEncryption" "${APP_DIR}/ios/Runner/Info.plist"; then
  echo "    OK: Info.plist includes ITSAppUsesNonExemptEncryption + PrivacyInfo.xcprivacy + 1024px AppIcon"
fi

if [[ -f "${APP_DIR}/ios/Runner/GoogleService-Info.plist" ]]; then
  echo "    OK: GoogleService-Info.plist found (Firebase APNs Push enabled)"
else
  echo "    NOTE: GoogleService-Info.plist not placed yet (app runs fine in local-alert mode; add before enabling remote Push)"
fi

echo "==> [2/6] Running Backend Pytest Suite..."
"${ROOT_DIR}/backend/.venv/bin/pytest" -q "${ROOT_DIR}/backend/tests"

echo "==> [3/6] Running Snapshot & FCM Dry-Run Integrity Checks..."
"${ROOT_DIR}/backend/.venv/bin/python" "${ROOT_DIR}/backend/publish_supabase.py" --snapshot-dir "${ROOT_DIR}/backend/output" --dry-run
"${ROOT_DIR}/backend/.venv/bin/python" "${ROOT_DIR}/backend/notify_fcm.py" --snapshot-dir "${ROOT_DIR}/backend/output" --dry-run

echo "==> [4/6] Running Flutter Static Analysis..."
cd "${APP_DIR}"
"${FLUTTER_BIN}" analyze

echo "==> [5/6] Running Flutter Unit & Widget Tests..."
"${FLUTTER_BIN}" test

if [[ -n "${CDN_BASE}" ]]; then
  echo "==> [6/6] Building Release iOS IPA pointing to ${CDN_BASE}..."
  "${FLUTTER_BIN}" build ipa --release \
    --dart-define="YALA_SNAPSHOT_CDN_BASE=${CDN_BASE}"
  echo "    IPA ready at: ${APP_DIR}/build/ios/ipa/"
else
  echo "==> [6/6] Pre-flight PASSED! To build a release IPA, pass your Supabase CDN URL as argument #1."
fi
