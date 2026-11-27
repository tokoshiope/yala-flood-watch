# Independent QA Audit & Re-Audit Report (v9) — `formula_version = 5` & 6-Point Founder Refinement (`1.0.1+10`)

- **Date:** 2026-11-27
- **Product:** แจ้งเตือนน้ำท่วมยะลา (Yala Flood Watch · `net.yala.floodapp` · `version: 1.0.1+10` · `province_code = "95"`)
- **Spec Reference:** `docs/specs/spec-unified-impact-early-warning-v5.md` (Gate 2 Approved) + 6 Founder Refinements + `AGENTS.md` Charter v3.0
- **Round 1 Independent Reviewer:** `research` subagent (`5b93cda5-d9ac-4240-852c-402c1d6f85fd`) → Verdict: **`HOLD`** (`0 BLOCKER, 0 HIGH, 4 MEDIUM, 5 LOW`)
- **Round 2 Fresh Independent Re-Auditor:** `research` subagent (`82f93393-7cb8-4e37-a2ca-71360106a957`) → Verdict: **`PASS`** (`0 BLOCKER, 0 HIGH, 0 MEDIUM, 2 non-blocking LOW` — both LOW hygiene items also resolved & re-verified post-audit)

---

## 1. Scope Audited

1. **Unified Impact-Based Early Warning Framework (`formula_version = 5`):**
   - Station calibration: `PAT002 watch_m = 13.30 m` (eliminating dry-day false Lv 2), `FOP045 datum_unverified = true` (bypassing `19.3 m` unverified bank-gap suppression).
   - Layer 1 proactive early warning up to Lv 4 (`compute_alert_v5` ↔ `AlertEngine.assessV5` 100% Python↔Dart parity, `time_to_bank_h <= 6h → Lv 4 / <= 24h → Lv 3`, `dam_inflow_daily_mcm >= 90`, `situation_level` 1–5 scale, non-water early warning cap at Lv 4).
   - Layer 2 Terrain Exposure Matrix (`Zone A / B / C` across all 449 DOPA villages & 356 DEM bands + Zone C Option ก advisory notes).
2. **Curved Zero-Overlap Administrative & Village Boundaries (`GeoThai/boundaries`):**
   - Rebuilt `yala_amphoes.geojson` (8 amphoes), `yala_subdistricts.geojson` (58 tambons, 6,075 curved vertices), and `yala_village_zones.geojson` (444 curved zones, 468 rings, 6-decimal precision) via exact planar half-edge curved Voronoi extraction.
   - Topology verified: `0.000000%` amphoe-vs-subdistrict area discrepancy (fixing Than To `+32.56%` / Betong `-18.69%`), `<= 0.000341%` tambon-vs-village-zone area discrepancy, `0` self-intersections, `0` pairwise edge crossings, byte-for-byte sync between `backend/registry/` and `mobile/app/assets/geo/`.
3. **Official Formal Thai Notification Copy (4-Language Sync):**
   - Formal, concise official Thai aligned with ปภ./สสน. across `pipeline.py`, `notify_fcm.py`, `risk_level.dart`, `alert_engine.dart`, `app_strings.dart`, and `guide_screen.dart` (`th`/`en`/`zh`/`ms`).
4. **24-Hour Rain Forecast `%` Display (`alerts_screen.dart`):**
   - `_RainForecastCard` unconditionally renders `%` rain probability (`0%`–`100%`) alongside `mm` and ICT hour on every bar without overflow at `375pt` / `1.35×`.
5. **Hybrid Offline-First App User Guide & Official DDPM Evacuation Guide:**
   - Embedded 100% offline 2-tab `guide_screen.dart` (4 languages) + shareable/printable web mirror `web/guide.html` (linked from `web/index.html`, `home_screen.dart`, `shelters_screen.dart`, `settings_screen.dart`), citing only verified ปภ. / สพฉ. 1669 guidance and contacts.
6. **Lean Hygiene Cleanup:**
   - Removed legacy `compute_alert_v2/v3/v4`, `fetch_community_reports_60m`, 5 dead Dart files (`sos_request.dart`, `sos_dispatch_service.dart`, `community_report_service.dart`, `rain_forecast.dart`, `rain_forecast_service.dart`), ~400 lines of unused localization keys, 11 stale snapshot files, and stray `./build/`.
7. **AI Team Charter v3.0 & Living Docs:**
   - Upgraded `AGENTS.md` to v3.0, created `docs/lessons-learned.md` (`LL-001`–`LL-012`) and `docs/data-provenance.md`.

---

## 2. Round 1 Findings → Fixes → Round 2 Verification Matrix

| ID | Severity | Round 1 Finding | Fix Applied & Permanent Regression Test | Round 2 Status |
|---|---|---|---|---|
| **MEDIUM-1** | MEDIUM | `_DrillListStrip` in `home_screen.dart:1478` called `elevationFloodLevel()` without `exposureZone` / `relHeightM` | Forwarded `exposureZone: v.exposureZone, relHeightM: v.relHeightM`; added regression test in `mobile/app/test/v1_0_1_improvements_test.dart:266-275`. | **FIXED** |
| **MEDIUM-2** | MEDIUM | `GuideScreen` quick-call hotline buttons hardcoded Thai labels across `en`/`zh`/`ms` | Added 4-language `_quickCallLabel()` in `guide_screen.dart:189-205,481-508`; added zero-Thai-leakage regression test across `en`/`zh`/`ms` in `mobile/app/test/sos_and_community_test.dart:116-146`. | **FIXED** |
| **MEDIUM-3** | MEDIUM | `FOP045` (`datum_unverified: true`) still exposed `bankLevel = 25.128 m` via `criticalLevel`/`watchLevel` and UI bank cards | Guarded `criticalLevel`, `watchLevel`, `hasBank`, `remainingToBank` in `station.dart` + UI guards in `station_detail_screen.dart` and `alerts_screen.dart`; added widget test asserting `25.13` never renders (`v1_0_1_improvements_test.dart:246-264`). | **FIXED** |
| **MEDIUM-4** | MEDIUM | `docs/data-provenance.md` cited stale `AGENTS.md §6` and draft OSM/GADM boundary sources | Updated to `AGENTS.md §2.2 & §5.1` and `GeoThai/boundaries` matching actual GeoJSON `source` metadata. | **FIXED** |
| **LOW-1** | LOW | Dead `communityReportTypeLabel()`, `sosDispatchedViaLabel()` in `app_strings.dart` and unused `maxStoredSosRequests` in `app_config.dart` | Deleted all dead methods/constants (`0` references). | **FIXED** |
| **LOW-2** | LOW | 5-decimal rounding caused 1 self-intersecting grazing sliver ring in `สะเตงนอก / บ้านปรามะ` | Upgraded `yala_village_zones.geojson` to 6-decimal precision + sliver filter (`>= 1e-9`) and added `test_geojson_zero_self_intersection_and_zero_pairwise_crossings` in `backend/tests/test_pipeline.py:797-862` (`0` self-intersections, `0` intra-tambon crossings). | **FIXED** |
| **LOW-3** | LOW | `docs/lessons-learned.md` had stale section/test/boundary citations | Fixed citations (`AGENTS.md §2 & §4.2`, `test_contacts_registry_has_verified_1784_and_yala_ddpm`, `GeoThai/boundaries`) and appended `LL-012`. | **FIXED** |
| **LOW-4** | LOW | `Station.riskLevel` `timeToBankH` lacked Python 2-decimal rounding | Rounded to 2 decimals in `station.dart:262-264`. | **FIXED** |
| **LOW-5** | LOW | Stale `v3`/`v4` comments in `pipeline.py`, `station.dart`, `home_screen.dart` | Cleaned all stale comments. | **FIXED** |

### Round 2 Non-Blocking LOW Observations (Also Resolved & Re-Verified Post-Audit)
- **`NEW-LOW-1`:** Added `station.hasBank` defense-in-depth guard to `_LevelTrendPainter.paint` (`station_detail_screen.dart:756`).
- **`NEW-LOW-2`:** Updated `situationLevel` doc comment (`1-4` → `1-5`) and removed unused `fillRatio` getter in `station.dart`, and deleted empty comment at `app_strings.dart:1161`.

---

## 3. Verbatim Final Verification Evidence (Executed After Final Edit)

| Suite / Check | Exact Command | Verbatim Result |
|---|---|---|
| **Live 5-Source Pipeline** | `backend/.venv/bin/python backend/pipeline.py --sync-mobile-asset` | `OK v5 stations=14 rain_gauges=86 amphoes=8 max_level=1 degraded=0 hash=1accf19148c7` |
| **Backend Unit, Parity & GIS Topology Tests** | `backend/.venv/bin/pytest -q backend/tests` | `50 passed, 1 warning in 0.90s` (`0` self-intersections, `0` pairwise crossings, `0.000000%` amphoe error) |
| **Supabase CDN Dry-Run** | `backend/.venv/bin/python backend/publish_supabase.py --dry-run` | `DRY_RUN_OK bucket=snapshots hash=1accf19148c7 stations=14 amphoes=8` |
| **FCM Push Dry-Run** | `backend/.venv/bin/python backend/notify_fcm.py --dry-run` | `FCM_DRY_RUN_OK count=0 topics=[]` |
| **Workflow & Registry YAML Lint** | `yaml.safe_load(...)` (5 files) | `YAML_OK` (`.github/workflows/data-pipeline.yml`, `deploy-pages.yml`, `stations.yaml`, `contacts.yaml`, `shelters.yaml`) |
| **iOS Plist & Entitlements Lint** | `plutil -lint mobile/app/ios/Runner/{Info.plist,PrivacyInfo.xcprivacy,Runner.entitlements}` | `Info.plist: OK`, `PrivacyInfo.xcprivacy: OK`, `Runner.entitlements: OK` |
| **Flutter Static Analysis** | `/Users/tokyo/flutter-sdk/bin/flutter analyze mobile/app` | `No issues found! (ran in 1.9s)` |
| **Flutter Unit, Parity, L10n & 375pt/1.35× Widget Tests** | `cd mobile/app && /Users/tokyo/flutter-sdk/bin/flutter test` | `+72: All tests passed!` |

---

## 4. Final Sign-Off

**VERDICT: `PASS`** — Ready for **Gate 3 (Founder Approval)** to push to GitHub (`tokoshiope/yala-flood-watch`) and build/upload TestFlight `1.0.1 (Build 10)`.
