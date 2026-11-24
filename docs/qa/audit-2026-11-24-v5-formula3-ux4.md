# Independent QA, Hydrology & Security Audit — Yala Flood Watch v0.5.0+5 / Formula v3 + UX v4

- **Date:** 2026-11-24
- **Auditor:** Independent QA / Hydrology & Security Reviewer Subagent (Separate Read-Only Context)
- **Initial Verdict:** `HOLD` (0 BLOCKER, 0 HIGH, 5 MEDIUM, 4 LOW)
- **Re-Audit Verdict:** **`PASS`** (0 BLOCKER, 0 HIGH, 0 MEDIUM, 2 non-blocking informational LOW)

---

## 1. Remediated Findings & Verification

| ID | Category | Finding | Remediation & Verification |
|---|---|---|---|
| **MEDIUM-1** | Pipeline / Sensor-Gap | When entire `thaiwater_rain_24h` feed failed (`amphoe_rain={}`), `normalize()` skipped `rain_sensor_gap` fallback for river-gauge amphoes | Added `rain_degraded: bool = False` to `backend/pipeline.py:normalize()` wired from `run_pipeline()` (`"thaiwater_rain_24h" in degraded`). Verified by `test_rain_degraded_outage_triggers_sensor_gap_fallback_in_normalize` (**RESOLVED**). |
| **MEDIUM-2** | Formula v3 Client Parity | `AlertEngine.evaluate()` pre-filtered using `leftBank` before calling `assessV3()`, missing สทภ.8 `critical_m < leftBank` (`X.77` 39.70m) & watch+rapid-rise overrides | Updated `mobile/app/lib/services/alert_engine.dart:evaluate()` to run `assessV3()` first and escalate when `shouldPush && level.value >= settings.warningLevel`. Verified by regression test in `v4_improvements_test.dart` (**RESOLVED**). |
| **MEDIUM-3** | iOS Dark Mode & WCAG Contrast | `WaterTrend`, `SosStatus`, and solid yellow `watch` (`0xFFF9A825`) pills had <4.5:1 contrast in Dark Mode / solid badges | Added `WaterTrend.colorFor(Brightness)`, `SosStatus.colorFor(Brightness)`, and dark ink `0xFF111827` via `RiskLevel.onColor` / `AlertLevel.onSolidColor` across all 6 screens & `StationMarker` (**RESOLVED**). |
| **MEDIUM-4** | Complete 4-Language i18n | 4 dynamic Thai strings remained in non-Thai modes (`_StationAlertsCard`, `_ErrorView`, subdistrict dropdown, village sheet) | Localized `_StationAlertsCard`, guarded `errorTh` for non-Thai locales, and added `AlertProvider.tumbonEnOf()` passed into `strings.tumbonName()` (**RESOLVED**). |
| **MEDIUM-5** | Fail-Closed Numeric Safety | Dart `_asDouble` & `_roundHalfUp1` did not reject non-finite `NaN`/`Infinity` values | Filtered `.isFinite` in `station.dart:_asDouble` and guarded `alert_engine.dart:_roundHalfUp1` (**RESOLVED**). |
| **LOW-1 / LOW-2** | Code Hygiene | Legacy `compute_alert_v2` returned `FORMULA_VERSION` (3); stale 2h hysteresis comments; `refresh()` omitted lazy-load of new GIS assets | Fixed legacy v2 tag to `2`, updated comments to v3 / 3h, and added lazy loading of `_villageZones`, `_elevationZones`, `_demGrid` in `AlertProvider.refresh()` (**RESOLVED**). |

---

## 2. Verified Checks Summary

- **Formula v3 Python ↔ Dart Parity:** Exact parity across all 6 weights (`0.38W + 0.22R + 0.10A + 0.12F + 0.10D + 0.08C`), piecewise impact-based `W` (`watch_m`/`critical_m` incl. สทภ.8 `X.40A` & `X.77`), `dH/dt`, `R1/R24/R72`, `API_7d`, `F + GloFAS`, `D + Bang Lang inflow surge`, Bank-Overflow / Flash Flood / Urban Pluvial / Dam Spillway overrides, 3h hysteresis, and 30m cooldown.
- **Automated Verification Evidence:**
  - `backend/.venv/bin/pytest -v backend/tests/test_pipeline.py` → **42/42 PASSED** (incl. TV3-1..TV3-10, 2024/2025 flood backtests, sensor-gap outage fallback, curved GIS & DEM checks).
  - `notify_fcm.verify_snapshot_integrity()` → **PASS** on both `backend/output/` and `mobile/app/assets/snapshots/` (`formula_version=3`, `degraded=0`, SHA-256 verified).
  - `flutter analyze --no-pub` → **0 issues**.
  - `flutter test --no-pub` → **66/66 PASSED** (incl. Formula v3 parity, Dark Mode widget tests, real station name `บ้านปายอยือนิ`, 4-language zero-Thai-leakage checks, PDPA pin wipe, and MEDIUM-2/3/5 regressions).
- **Curved GIS & DEM Assets:** Byte-identical between `backend/registry/` and `mobile/app/assets/geo/`: 8 amphoes (avg 140 verts), 58 subdistricts (avg 42.2 verts, GADM 4.1), 422 curved village zones, 356 topographic elevation bands, 81×57 Copernicus DEM grid (100% Yala coverage), and 449 DOPA villages.
- **PDPA & Zero-Hallucination Emergency Contacts:** GPS consent dialog gates all `Geolocator` calls (`When In Use` only); Yala bbox enforced on GPS and manual pin; `pinnedLocationPrefsKey` erased in `deleteAllUserData()`; verified emergency contacts (`1784`, `073-203559`, `073-212345`, `1669`) intact.

---

## 3. Residual Informational Notes (Non-Blocking)
- `LOW-3`: `AlertProvider.deleteAllUserData()` re-syncs generic non-PII topic `yala_flood_all` if FCM is active (zero PII).
- `LOW-4`: `mobile/app/ios/Flutter/Generated.xcconfig` (`0.4.0+4`) will automatically update to `0.5.0+5` when running `flutter build ios` / TestFlight archive.
