# Independent QA Audit & Re-Audit Report v10 — P0–P2 Startup Production Overhaul

> **Date:** 2026-11-27 · **Scope:** P0–P2 Reliability, Compliance, UX, Performance & Backtest Overhaul (`spec-p0-p2-startup-upgrade.md`)
> **Round 1 Verdict:** `HOLD` (0 BLOCKER, 2 HIGH, 5 MEDIUM, 6 LOW)
> **Round 2 Final Verdict:** **`PASS`** (0 BLOCKER, 0 HIGH, 0 MEDIUM remaining)

---

## 1. Automated Verification Evidence (Post-Final-Edit)

| Check | Exact Command | Result |
|---|---|---|
| Backend Unit, Formula v5, Topology & Ops Tests | `backend/.venv/bin/pytest -q backend/tests` | **53 passed** (`0.86s`) |
| Historical Flood Backtest Replay (2567–2568) | `backend/.venv/bin/python backend/backtest_yala_2567_2568.py --write-report docs/qa/backtest-yala-2567-2568.md` | **`BACKTEST_PASS v5 total=9 POD=1.00 FAR=0.00 CSI=1.00`** |
| Supabase Publisher Dry-Run | `backend/.venv/bin/python backend/publish_supabase.py --snapshot-dir backend/output --dry-run` | **`DRY_RUN_OK`** (`stations=14`, `amphoes=8`, SHA-256 verified) |
| FCM Notifier Dry-Run | `backend/.venv/bin/python backend/notify_fcm.py --snapshot-dir backend/output --dry-run` | **`FCM_DRY_RUN_OK`** (`count=0`) |
| Workflow YAML Validation | `yaml.safe_load` on all 3 `.github/workflows/*.yml` | **`YAML_OK`** |
| iOS Plist & Privacy Manifest Lint | `plutil -lint mobile/app/ios/Runner/{Info.plist,PrivacyInfo.xcprivacy,Runner.entitlements}` | **3/3 `OK`** |
| Flutter Static Analysis | `/Users/tokyo/flutter-sdk/bin/flutter analyze mobile/app` | **`No issues found!`** |
| Flutter Unit, Security & 375pt/1.35× Widget Tests | `/Users/tokyo/flutter-sdk/bin/flutter test` | **83 passed (100%)** |
| Static l10n Key & Leakage Audit (Re-Audit) | All `strings.get(...)` across `mobile/app/lib/**/*.dart` | **`DICT_KEYS=205, MISSING_KEYS=0, MISSING_LANGS=0, THAI_LEAKS_IN_DICT=0`** |
| iOS Simulator Live Build | `flutter build ios --simulator --debug --dart-define=YALA_SNAPSHOT_CDN_BASE=...` | **`✓ Built build/ios/iphonesimulator/Runner.app`** (`net.yala.floodapp` launched on iPhone 18 Pro Simulator) |

---

## 2. Round 1 Findings & Round 2 Closure Verification

- **H-1 (FIXED):** Replaced missing `'banglang_dam'` with `'dam_title'`, added 4-language keys (`exposure_zone_label`, `zone_short_prefix`, `share_level_prefix`, `share_lead_time_label`, `share_emergency_line`, `remove_place_title`, `remove_place_confirm`), added `formatLeadTime()` & `zoneBadgeText()` for both `share_status_sheet.dart` and `voiceBriefingText()`, and added automated tests asserting zero raw keys and zero Thai characters in `en`/`zh`/`ms`.
- **H-2 (FIXED):** `AlertProvider.deleteAllUserData()` clears `_stationHistory7d` and calls `await _notifications.syncTopics(pushEnabled: false, topics: const <String>{})` BEFORE `_store?.deleteAllUserData()` so PDPA full wipe unsubscribes active topics and never re-persists topic keys.
- **M-1 (FIXED):** `main.dart` defers `NotificationService.instance.registerNavigationHandler` via `addPostFrameCallback`, retries once if `navigatorKey.currentState == null`, and clears `onNavigateRoute = null` in `dispose()`.
- **M-2 (FIXED):** `AppDelegate.swift` tracks `activeUtterance` before cancelling prior speech, guards `didFinish`/`didCancel` against stale utterances, and calls `AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])` on finish/cancel/stop.
- **M-3 (FIXED):** Corrected `BT-2567-02` (`X.77`) in `backend/backtest_yala_2567_2568.py` to `อ.ธารโต` (`bank_m=40.30, critical_m=39.70`), added explicit `provenance_tier` per scenario, and clearly marked `BT-SYN-01` as a synthetic no-gauge flash-flood stress test (`docs/qa/backtest-yala-2567-2568.md`).
- **M-4 (FIXED):** `CachingTileProvider` validates PNG/JPEG/WebP magic bytes (`isValidTileImageBytes`), performs atomic `.tmp -> rename` disk writes, wraps `decode()` with corrupt-file eviction + transparent PNG fallback, and performs async throttled eviction every 25 writes (zero `listSync()` on UI thread).
- **M-5 (FIXED):** Updated LINE Share button to `#00883A` (`4.58:1` WCAG AA contrast on white), removed silent `onLongPress` deletion in `FamilyWatchStrip` in favor of a confirmation dialog, enlarged action icon tap targets + tooltips, and localized `Zone` badges across all 4 languages.
- **LOW 1–4 (FIXED):** Isolated `_send_ops_signal` heartbeat/webhook try/except blocks in `pipeline.py`, added `subdistricts.length` & station `displayLevel` to `HomeScreen` polygon memoization key, updated `app_config.dart` header comment, and declared `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) in `PrivacyInfo.xcprivacy`.
- **Lessons Learned:** Logged as `LL-013` in `docs/lessons-learned.md`.
