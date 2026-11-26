# Independent QA Audit & Re-Audit Report (v8) — `formula_version = 4` Water-Stage Primary Alert Engine (`DEC-021`)

- **Date:** 2026-11-27
- **Auditor:** Independent Hydrology & Security QA Subagent (Read-Only Separate Context per `AGENTS.md §4`)
- **Spec Reference:** `docs/specs/spec-water-stage-alert-v4.md`
- **Final Verdict:** **`PASS`** (Initial Audit: `HOLD` due to 1 BLOCKER + 4 MEDIUM + 4 LOW → All Resolved & Re-Verified)

---

## 1. Automated Verification Evidence
- **Python Backend (`pytest`):** `67/67 passed` (includes `TV4-1`..`TV4-14`, `normalize()` `situation_level=5/4` regression, and `notify_fcm` `rain_dam_early_warning` basis tag + lead time on both amphoe & `yala_flood_all` topics).
- **Flutter Static Analysis (`flutter analyze`):** `0 issues`
- **Flutter Test Suite (`flutter test`):** `99/99 passed` (includes 100% Python ↔ Dart score/level/basis/trend/push parity on `TV4-1`..`TV4-14`, Option 1 rain cap `<= Lv 3`, and 3-hour hysteresis hold/release in `evaluate()`).
- **Snapshot Integrity:** `backend/output/latest.json`, `backend/output/snapshot-20261127-063500-f1813715.json`, `backend/output/manifest.json`, and `mobile/app/assets/snapshots/{latest,manifest}.json` all match `formula_version = 4` and SHA-256 `f18137154998d11a66c956a869b31472cd164b0ba69b2a512cfc2a06a2801ff4`.

---

## 2. Re-Audit Verification Matrix (All Initial Findings Resolved)

| Finding | Initial Severity | Status | Verified Fix (`file:line`) |
|---|---|---|---|
| `normalize()` dropped ThaiWater `situation_level == 5` (`1 <= sit_raw <= 4`) | **BLOCKER-1** | **RESOLVED** | `backend/pipeline.py:1565` updated to `1 <= sit_raw <= 5`; `pipeline.py:832` & `alert_engine.dart:303` check `>= 5`; regression test `test_normalize_preserves_thaiwater_situation_level_5_and_4_correctly` passes. |
| `AlertEngine.effectiveRisk()` could escalate rain beyond Option 1 Lv 3 cap | **MEDIUM-1** | **RESOLVED** | `mobile/app/lib/services/alert_engine.dart:933-938` caps rain escalation strictly at `RiskLevel.warning` (Lv 3); regression test added (`alert_engine_test.dart:538-558`). |
| `AlertEngine.evaluate()` bypassed 3h hysteresis when `shouldPush == false` | **MEDIUM-2** | **RESOLVED** | `mobile/app/lib/services/alert_engine.dart:990-992` preserves held level via `heldByHysteresis`; regression test verifies 1h hold & 3h+5m release (`alert_engine_test.dart:560-590`). |
| `yala_flood_all` topic omitted rain/dam basis tag & dam lead time | **MEDIUM-3** | **RESOLVED** | `backend/notify_fcm.py:218-223` appends `(เตือนภัยล่วงหน้าจากฝน/เขื่อน)` & `(คาดน้ำเดินทางถึงใน {lead})` matching per-amphoe topics; regression test added (`test_pipeline.py:719-743`). |
| `manifest.json["snapshot"]` referenced older v3 archive filename | **MEDIUM-4** | **RESOLVED** | Created `backend/output/snapshot-20261127-063500-f1813715.json` (`formula_version = 4`), updated `manifest.json` and synced `mobile/app/assets/snapshots/` byte-identically. |
| `StationDetailScreen` chart plotted `bankLevel` instead of `criticalLevel` & bypassed `watchLevel` | **LOW-1** | **RESOLVED** | `mobile/app/lib/screens/station_detail_screen.dart:538-539,754` now use `station.criticalLevel ?? station.bankLevel` and `station.watchLevel`. |
| `Station.trend` used `< 0.05` vs `<= 0.05` steady band | **LOW-2** | **RESOLVED** | `mobile/app/lib/models/station.dart:307-309` rounds `diff` to 4 decimals and checks `diff.abs() <= AppConfig.steadyBandMeters`. |
| `SettingsScreen` `warningLevel` dropdown unclamped | **LOW-3** | **RESOLVED** | `mobile/app/lib/screens/settings_screen.dart:154,180` clamp both `warningLevel.clamp(2, 4)` and `dangerLevel.clamp(3, 5)`. |
| `test_pipeline.py` lacked score assertions & `TV4-13`/`TV4-14` vectors | **LOW-4** | **RESOLVED** | Both `test_pipeline.py:561-689` and `alert_engine_test.dart:267-496` assert exact scores on all 14 vectors (`TV4-1`..`TV4-14`). |

---

## 3. Remaining Findings
- **BLOCKER:** None
- **HIGH:** None
- **MEDIUM:** None
- **LOW:** None

**Sign-Off:** **PASS** — Ready for Founder **Gate 3** approval (Push GitHub / Rebuild TestFlight if desired).
