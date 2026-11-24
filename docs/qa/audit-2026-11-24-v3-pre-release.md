# Independent Pre-Release v3 / Gate 3 QA Audit & Re-Audit Report

- **Date:** 2026-11-24
- **Target:** **แจ้งเตือนน้ำท่วมยะลา (`Yala Flood Watch`)** — `/Users/tokyo/Documents/Yala Flood`
- **Auditor:** Independent Pre-Release QA Auditor (`research` subagent, separate read-only context `d3d66b4b-e886-4fa9-bc9a-096a4af04448`)
- **Initial Audit Verdict:** `HOLD` (0 BLOCKER, 3 HIGH, 3 MEDIUM, 3 LOW)
- **Final Re-Audit Verdict:** **`PASS`** ✅ *(0 BLOCKER, 0 HIGH, 0 MEDIUM, 1 LOW informational pre-TestFlight reminder)*

---

## 1. Independent Remediation Verification Table (8/8 Resolved)

| ID | Severity | Issue Found in Round 1 | Resolution & Direct Verification Evidence | Status |
|---|---|---|---|---|
| **HIGH-1** | HIGH | `PrivacyInfo.xcprivacy` existed on disk but was not linked in `project.pbxproj` (`objectVersion = 54`), risking Apple ITMS-91053 rejection | Linked `PrivacyInfo.xcprivacy` into `PBXFileReference`, `Runner` `PBXGroup`, `PBXBuildFile`, and `PBXResourcesBuildPhase` via Swift script; `plutil -lint project.pbxproj Info.plist PrivacyInfo.xcprivacy` → **3/3 OK** | **FIXED** ✅ |
| **HIGH-2** | HIGH | `data-pipeline.yml` ran `notify_fcm.py` without persisted state (bypassing 30m cooldown), and `notify_fcm.py` did not decay/reset Level 4–5 state after a storm ended | Added `HYSTERESIS_SECONDS = 2 * 3600` expiry + `reconcile_state(...)` in `backend/notify_fcm.py` and persisted `backend/output/fcm_state.json` via `actions/cache@v4` in `.github/workflows/data-pipeline.yml`; verified via `pytest` + dry-run (`FCM_STATE_REAUDIT_OK`, `FCM_DRY_RUN_OK`) | **FIXED** ✅ |
| **HIGH-3** | HIGH | `SosScreen.build()` cleared `_phoneController` whenever `!provider.gpsConsentGranted`, erasing a typed phone number before GPS consent | Added monotonic `AlertProvider.dataResetVersion` incremented exclusively inside `deleteAllUserData()` and handled reset inside `_SosScreenState.didChangeDependencies()` | **FIXED** ✅ |
| **MEDIUM-1** | MEDIUM | Mobile `SnapshotService` fetched `latest.json` without verifying `manifest.json` `content_hash` or caching verified CDN snapshots locally | Updated `SnapshotService.loadSnapshot()` to verify `manifest.json` `content_hash`, `province.code == '95'`, and 8 amphoes fail-closed, caching verified JSON under `AppConfig.cacheSnapshotKey` (`CDN → Local Cache → Bundled Asset`) | **FIXED** ✅ |
| **MEDIUM-2** | MEDIUM | `project.pbxproj` Bundle ID (`net.yala.yalaFloodApp`) diverged from `app_config.dart`/`Info.plist` (`net.yala.floodapp`), and `pubspec.yaml` was `0.3.0+3` vs `0.4.0` | Aligned all 3 Xcode configs to `net.yala.floodapp` (`RunnerTests` → `net.yala.floodapp.RunnerTests`) and aligned `pubspec.yaml` to `0.4.0+4` | **FIXED** ✅ |
| **MEDIUM-3** | MEDIUM | `AlertProvider.deleteAllUserData()` did not resync FCM topic subscriptions after resetting amphoe preference | Added `await _notifications.syncTopicSubscription(...)` inside `deleteAllUserData()` | **FIXED** ✅ |
| **LOW-1** | LOW | Village tooltip in `mobile/preview/index.html:1211` interpolated strings without `esc(...)` | Wrapped `v.moo`, `v.name_th`, `v.elevation_msl`, and `ev.text` in `esc(...)` | **FIXED** ✅ |
| **LOW-2** | LOW | Public `SELECT` RLS policy on `community_reports` exposed `device_hash` column | Restricted raw `community_reports` `SELECT` to `service_role` and created anonymized `public.public_community_reports` view omitting `device_hash` granted to `anon, authenticated` | **FIXED** ✅ |

---

## 2. Core Life-Safety & App Store Checks Passed

- **iOS Assets & Plists:** 15 unique AppIcon PNGs (19 slots, `Icon-App-1024x1024@1x.png` verified `1024x1024`, `hasAlpha: no`); `Info.plist` (`CFBundleDisplayName=แจ้งเตือนน้ำท่วมยะลา`, `When In Use` only, `ITSAppUsesNonExemptEncryption=false`, `UIBackgroundModes=[remote-notification]`, `LSApplicationQueriesSchemes` incl. `line`, `fb`); `PrivacyInfo.xcprivacy` (`NSPrivacyTracking=false`, `UserDefaults CA92.1`) — all `plutil -lint OK`.
- **Formula v2 Parity & Citizen UI Cleanliness:** `backend/pipeline.py` ↔ `mobile/app/lib/services/alert_engine.dart` 100% parity (TV2-1..TV2-10). Zero technical jargon (`formula_version`, `คะแนนความเสี่ยง`, `SHA-256`, `W/R/F/D/C`) in citizen UI or FCM push messages.
- **Yala Geo & Elevation Parity:** Exact SHA-256 parity between `backend/registry/` and `mobile/app/assets/geo/` (`8` amphoes, `58` subdistricts, `449` DOPA villages with Copernicus DEM MSL).
- **Zero-Hallucination Contacts & Shelters:** Verified `1784`, `073-203559`, `073-212345`, `1669`, `199`, `191`, `073-228934`, `073-340141`, `1677` + HTTP 200 LINE/FB links; 12/12 shelters match `shelters.yaml` v3; zero `"พิกัดโดยประมาณ"` badge; all 7 non-city shelters marked `"อ้างอิงจากข้อมูลเดิม รอยืนยัน"`.
- **Automated Test Suites:**
  - `pytest -v backend/tests` → **28/28 PASSED**
  - `flutter analyze` → **No issues found**
  - `flutter test` → **45/45 PASSED**
  - `publish_supabase.py --dry-run` → **`DRY_RUN_OK`**
  - `notify_fcm.py --dry-run` → **`FCM_DRY_RUN_OK`**

---

## 3. Non-Blocking Pre-TestFlight Founder Reminder (`LOW-3`)

- Before archiving in Xcode for TestFlight / App Store Connect, Founder enables the **Push Notifications** capability (`aps-environment` in `Runner.entitlements`) in Xcode Signing & Capabilities and places Firebase's `GoogleService-Info.plist` (matching `net.yala.floodapp`) into `mobile/app/ios/Runner/`.

**Gate 3 Sign-Off:** **`PASS`** — Ready for Founder manual setup (Track 1) and Gate 3 release approval.
