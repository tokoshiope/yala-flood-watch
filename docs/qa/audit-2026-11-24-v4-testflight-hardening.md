# Independent Pre-TestFlight QA, Lean, Stability & Security Audit Report (v4)

- **Date:** 2026-11-24
- **Target:** แจ้งเตือนน้ำท่วมยะลา (`Yala Flood Watch` · `net.yala.floodapp` · `0.4.0+4`)
- **Reviewer:** Independent Read-Only Subagent (`d86035f5-968a-4347-b347-98d6daa2d587`, separate context per `AGENTS.md §4`)
- **Initial Audit Verdict:** `HOLD` (0 BLOCKER, 1 HIGH, 2 MEDIUM, 5 LOW)
- **Final Re-Audit Verdict:** **`PASS`** ✅ (0 BLOCKER, 0 HIGH, 0 MEDIUM, 3 post-launch/hygiene LOWs)

---

## 1. Pre-Upload Hardening Summary

Before uploading to Apple TestFlight, the codebase underwent a comprehensive lean, real-device iOS stability, and security hardening pass:

1. **iOS Real-Device Push & Lean FCM Topic Sync (`mobile/app/lib/services/notification_service.dart`):**
   - Added bounded Apple APNs token readiness wait (`12 × 500ms = 6s` cap) before marking `_pushConfigured = true` and calling `subscribeToTopic()`, preventing cold-start `[firebase_messaging/apns-token-not-set]` errors on physical iPhones.
   - Added single-guarded `messaging.onRegistered` listener with `forceResync: true` to keep topic subscriptions synchronized on token arrival/refresh.
   - Persisted subscribed topic in `SharedPreferences` (`AppConfig.subscribedTopicPrefsKey`), reducing cold-start FCM network round-trips from **9 calls → 0 calls** when unchanged (and **2 calls** when switching amphoe).
2. **Instant Startup & Lifecycle Refresh (`mobile/app/lib/main.dart`, `mobile/app/lib/state/alert_provider.dart`):**
   - Moved `NotificationService.instance.initializePush()` to non-blocking `unawaited(...)` so app first-frame rendering is instant even offline during a flood.
   - Eliminated duplicate remote Supabase CDN fetch on startup: `hydrate()` now loads all 3 geographic layers (`8 amphoes`, `58 subdistricts`, `449 villages`) + local cached/bundled snapshot in parallel via `Future.wait`, followed by a single live `refresh()`.
   - Wired `WidgetsBindingObserver` (`AppLifecycleState.resumed`) → `provider.refreshIfStale()` honoring `settings.refreshMinutes` without draining background battery.
   - Added `_disposed` guard on `notifyListeners()` and proper HTTP client cleanup in `dispose()`.
3. **Fail-Closed CDN & Client Security (`mobile/app/lib/services/snapshot_service.dart`, `thai_water_service.dart`, `sos_screen.dart`, `shelters_screen.dart`, `local_store.dart`):**
   - Enforced strict `https://` scheme on CDN snapshot requests and parallel `manifest.json` + `latest.json` fetch with explicit UTF-8 decoding (`utf8.decode(bodyBytes)`) and trailing-slash normalization.
   - Added Yala bounding-box (`lat 5.5–7.2`, `lon 100.5–101.9`), non-numeric `TypeError`, and `NaN` fail-closed guards in `SnapshotService.isValidYalaSnapshot()` plus `catch (_)` fallback protection.
   - Added 15-second GPS timeout (`LocationSettings.timeLimit`), strict `https` external URL checks, sanitized `tel:` dialer, and verified complete PDPA wipe (`LocalStore.deleteAllUserData()` clears all 5 user keys including `subscribedTopicPrefsKey`).

---

## 2. Independent Audit & Re-Audit Remediations (5/5 Resolved)

| ID | Severity | Issue Found | Remediation & Re-Audit Evidence | Status |
|---|---|---|---|---|
| **HIGH-1** | HIGH | Initial IPA (`14:41:36`) predated hardening edits (`14:52–15:04`). | Rebuilt via `./scripts/release_preflight.sh "https://ibrdiroqzgqykxpttafj.supabase.co/storage/v1/object/public/snapshots"`. `stat` confirms fresh `yala_flood_app.ipa` (`24.0 MB`, `15:07:01`) newer than all `.dart` edits, bundling `GoogleService-Info.plist` + `PrivacyInfo.xcprivacy` + `aps-environment=production` + `beta-reports-active=true`. | **FIXED** ✅ |
| **MEDIUM-1** | MEDIUM | `_pushConfigured = true` was set before awaiting `_waitForAppleApnsTokenIfNeeded()`, risking premature `subscribeToTopic()` from `hydrate()`. | Moved `_pushConfigured = true` immediately after `await _waitForAppleApnsTokenIfNeeded(messaging)` (`notification_service.dart:121-126`). | **FIXED** ✅ |
| **MEDIUM-2** | MEDIUM | Non-numeric `lat`/`lon` in tampered payload threw `TypeError` escaping `on Exception`. | Added explicit `is! num` + `isNaN` checks and `catch (_)` in `snapshot_service.dart:63-75, 97, 111, 163` + regression test in `security_and_hardening_test.dart:62-66`. | **FIXED** ✅ |
| **LOW-1** | LOW | Trailing `/` in `YALA_SNAPSHOT_CDN_BASE` produced `//latest.json`. | Added `_normalizedBaseUrl` stripping trailing slashes (`snapshot_service.dart:28-41`). | **FIXED** ✅ |
| **LOW-2** | LOW | `ThaiWaterService` used `response.body` instead of explicit UTF-8 decode. | Switched to `utf8.decode(response.bodyBytes)` (`thai_water_service.dart:110`). | **FIXED** ✅ |

---

## 3. Verified Security, Secrets & Automated Test Matrix

- **Backend `pytest`:** `28/28 passed`
- **Snapshot & FCM Dry-Run (`publish_supabase.py`, `notify_fcm.py`):** `DRY_RUN_OK` & `FCM_DRY_RUN_OK`
- **Flutter Static Analysis (`flutter analyze`):** `0 issues`
- **Flutter Unit & Widget Tests (`flutter test`):** `50/50 passed` (including 5 new tests in `test/security_and_hardening_test.dart`)
- **Apple Plists (`plutil -lint`):** 5/5 `OK` (`Info.plist`, `PrivacyInfo.xcprivacy`, `Runner.entitlements`, `GoogleService-Info.plist`, `project.pbxproj`)
- **Secrets & Git Hygiene:** Zero hardcoded secrets/tokens in `mobile/app/lib/` or git-tracked files; `GoogleService-Info.plist` properly gitignored.
- **Supabase RLS & Live CDN:** RLS enforced on `community_reports`; `public_community_reports` excludes `device_hash`; live `https://ibrdiroqzgqykxpttafj.supabase.co/storage/v1/object/public/snapshots/manifest.json` & `latest.json` verified `HTTP 200 OK` (5/5 sources healthy, `degraded_sources: []`).

### Remaining Non-Blocking Notes (Post-Launch)
- **LOW-3:** Close `RainForecastService` HTTP client once external forecast endpoint is used.
- **LOW-4:** Optional Apple `Time Sensitive Notifications` entitlement for Level 4–5 Focus-mode breakthrough.
- **LOW-5:** Schedule `purge_expired_reports()` in GitHub Actions and add advisory/row locking to `submit_community_report` before enabling public community submission UI.

---

**Final Sign-Off:** **`PASS`** — Cleared for TestFlight upload (`0.4.0+4`).
