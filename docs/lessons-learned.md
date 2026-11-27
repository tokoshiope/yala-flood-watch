# Yala Flood Watch — Living Lessons Learned & Error Registry

> **Mandatory Rule (`AGENTS.md §2 & §4.2`):** Before modifying code, registries, GeoJSON boundaries, formulas, or UI in any domain below, agents **MUST** scan this file so the AI team never repeats a historical mistake. Every defect found by the Founder, CI, or Independent QA **MUST** be appended here with root cause, permanent guardrail/regression test, and evidence link.

---

## LL-001 — Misidentified Emergency Number (`1677` vs `1784`)
- **Date:** 2026-11-24 · **Domain:** Emergency Contacts (`backend/registry/contacts.yaml`, `AppConfig`)
- **Mistake:** Early prototype listed `1677` as DDPM (กรม ปภ.). In reality, `1677` is Ruamduay Chuaykan (ร่วมด้วยช่วยกัน — volunteer foundation), while Thailand's official DDPM hotline is **`1784`** (plus `073-203559` ปภ.ยะลา and `073-212345` เทศบาลนครยะลา).
- **Fix:** Corrected all registries, app config, and legal web pages (`DEC-013`), separated `1677` explicitly as volunteer, and verified official LINE/Facebook URLs via HTTP 200.
- **Permanent Guardrail:** Every emergency number MUST cite an authoritative source in `docs/data-provenance.md` and pass `test_contacts_registry_has_verified_1784_and_yala_ddpm` in `backend/tests/test_pipeline.py`.

## LL-002 — ThaiWater `situation_level` 1–5 Scale Misinterpretation
- **Date:** 2026-11-27 · **Domain:** Alert Engine (`backend/pipeline.py`, `alert_engine.dart`, `risk_level.dart`, `station.dart`)
- **Mistake:** Early formulas (`v1`–`v3`) treated ThaiWater `situation_level` as a 1–4 flood-alert scale where `3 = Warning` and `4 = Danger`. In ThaiWater API v3 (สสน.), `situation_level` is a **1–5 water-capacity scale**: `1 = น้อยวิกฤต (≤10%)`, `2 = น้อย (10–30%)`, `3 = ปกติ (30–70%)`, `4 = มาก (70–100%)`, `5 = ล้นตลิ่ง (>100%)`. Treating `sit=3` as Warning or `sit=4` as Danger triggered chronic false alarms on normal dry days.
- **Fix:** Fixed scale mapping across Python & Dart (`DEC-021`): `1–3 = Normal`, `4 = Watch fallback ONLY for unbanked/unverified stations`, `5 = Confirmed Overflow (Lv 5)`.
- **Permanent Guardrail:** Parity test vectors verify `sit=3` stays Lv 1 and `sit=4` below `watch_m` does NOT trigger Lv 3–5.

## LL-003 — `PAT002` Controlled Weir Pool Causing Dry-Day Lv 2 False Watch
- **Date:** 2026-11-27 · **Domain:** Station Thresholds (`backend/registry/stations.yaml`, `AppConfig`)
- **Mistake:** `PAT002` (หน้าเขื่อนทดน้ำปัตตานี ต.ตาเซะ) had `watch_m = 12.35 m`, whereas its normal controlled irrigation pool sits at `12.43–13.00 m MSL`, keeping Mueang Yala permanently in Lv 2 Watch on sunny days.
- **Fix:** Calibrated `PAT002` `watch_m` to **`13.30 m`** (`mid = 13.575`, `high = 13.7125`, `critical_m = 13.85`) in `formula_version = 5` (`spec-unified-impact-early-warning-v5.md`).
- **Permanent Guardrail:** Whenever setting `watch_m` for a controlled weir/barrage station, verify against 7-day dry-season baseline water levels before committing.

## LL-004 — `FOP045` Datum Mismatch (`level 5.79 m` vs `bank 25.128 m`)
- **Date:** 2026-11-27 · **Domain:** Station Datum Calibration (`stations.yaml`, `pipeline.py`, `alert_engine.dart`, `station.dart`)
- **Mistake:** Station `FOP045` (สะพานกรงปินัง) reports `waterlevel_msl ~ 5.79` against `ground_level = 5.95` and `left_bank = 25.128` (a `19.3 m` gap likely caused by mixed local staff-gauge datum vs MSL bank datum). Using `bank - level` blindly suppressed real flood risk.
- **Fix:** Flagged `datum_unverified: true` in `stations.yaml` and `AppConfig.unverifiedDatumStations`. When `datum_unverified=True`, bypass `bank - level` suppression, evaluate via `dH/dt`, `situation_level == 5`, and rain/dam signals, and set `confidence = "medium"`.
- **Permanent Guardrail:** Audit `bank - level` sanity (`0 < bank - ground < 15 m` for alluvial gauges) for every new station; flag anomalies explicitly instead of silently trusting them.

## LL-005 — Amphoe vs Subdistrict Boundary Mismatch (Than To `+32.56%` / Betong `-18.69%`)
- **Date:** 2026-11-27 · **Domain:** GeoJSON Boundaries (`yala_amphoes.geojson`, `yala_subdistricts.geojson`)
- **Mistake:** `yala_amphoes.geojson` came from GADM level-2 while `yala_subdistricts.geojson` came from GADM level-3 where `ต.แม่หวาด (950403)` is rightly in อ.ธารโต, causing a `+32.56% / -18.69%` boundary overlap/misalignment between อ.ธารโต and อ.เบตง. Independent polygon simplification also created sliver overlaps between adjacent tambons.
- **Fix:** Sourced high-resolution topologically aligned administrative boundaries (`GeoThai/boundaries`, DOPA-aligned, 6,075 vertices across 58 tambons) where `yala_amphoes.geojson` matches the exact sum of its 58 constituent tambons (`0.00000%` area discrepancy, `100%` shared boundary arcs).
- **Permanent Guardrail:** Automated topology validator checks `abs(sum(sub_area) - amp_area) / amp_area < 0.001` for all 8 amphoes and zero pairwise overlap before any GeoJSON commit.

## LL-006 — Coarse Raster Village Zones Creating Stair-Steps & Tambon Misalignment
- **Date:** 2026-11-27 · **Domain:** Village Zone Boundaries (`yala_village_zones.geojson`)
- **Mistake:** `yala_village_zones.geojson` was generated by rasterizing Voronoi cells onto a coarse lat/lon grid and contouring them. This produced chunky horizontal/vertical stair-steps AND left `-6.15%` to `+1.78%` mismatches/overlaps against the curved tambon outline (`02-map-village-elevation.png`).
- **Fix:** Replaced raster contouring with **exact vector polygon clipping** against the exact curved tambon polygon plus **shared curved internal dividers** (each shared edge between Village A and Village B uses the exact same smooth curve, reversed for the neighbor). Result: `0.00%` overlap, `0.00%` gap, `100.00%` exact alignment with the outer tambon boundary.
- **Permanent Guardrail:** Automated geometry audit verifies `sum(village_zone_area) / tambon_area == 1.000 ± 0.001` across all 58 tambons and zero horizontal/vertical grid stair-steps.

## LL-007 — `%` Rain Probability Hidden on Rainy Hours in Forecast Chart
- **Date:** 2026-11-27 · **Domain:** Flutter UI (`mobile/app/lib/screens/alerts_screen.dart`)
- **Mistake:** `_RainForecastCard` used `pt.mm >= 0.1 ? mm : (pt.probPct >= 25 ? '%' : '')`, hiding `%` rain probability whenever rain `>= 0.1 mm` or `< 25%` (`02-iphone-rain-forecast.png`).
- **Fix:** Rendered a dedicated `%` rain probability row for **every single hour bar (0%–100%)** alongside the `mm` bar value, with sufficient vertical clearance and `FittedBox` scaling for 375pt screens and 1.35× large text.
- **Permanent Guardrail:** Widget regression test asserts every visible hour bar renders its `%` label without RenderFlex overflow at `375×812` and `textScaler = 1.35`.

## LL-008 — iOS Dark Mode Contrast & 375pt / 1.35× Large-Text Overflow
- **Date:** 2026-11-24 / 2026-11-26 · **Domain:** Flutter UI (`home_screen.dart`, `alerts_screen.dart`, `sos_screen.dart`, `shelters_screen.dart`)
- **Mistake:** Light-mode-only colors failed WCAG AA contrast in iOS Dark Mode, and fixed `Row` layouts overflowed on 375pt iPhones with `largeTextMode = true` (`1.35×`).
- **Fix:** Standardized brightness-aware colors (`colorFor(brightness)`), `Wrap` / `FittedBox` / `Expanded` layouts, and high-contrast map pills (`#0F172A` / `#FFFFFF`).
- **Permanent Guardrail:** Every new/modified Flutter screen MUST have a widget test rendered at `Size(375, 812)` with `TextScaler.linear(1.35)` in both Light and Dark themes.

## LL-009 — Apple Guideline 2.1 Privacy / UGC Alignment
- **Date:** 2026-11-26 · **Domain:** iOS App Store Compliance (`PrivacyInfo.xcprivacy`, `Info.plist`, `sos_screen.dart`)
- **Mistake:** Leaving unused UGC / SOS dispatch code, `sms` URL scheme, or mismatched privacy declarations risked Apple Guideline 2.1 / App Privacy rejection.
- **Fix:** Removed SOS dispatch & UGC (`DEC-020`), aligned `PrivacyInfo.xcprivacy` to `NSPrivacyCollectedDataTypes = []` ("Data Not Collected"), and pruned all dead SOS/UGC Dart files (`sos_request.dart`, `sos_dispatch_service.dart`, `community_report_service.dart`) while preserving PDPA key cleanup on upgrade.
- **Permanent Guardrail:** Whenever a feature is removed from UI, delete its dead models/services/strings in the same commit and run `grep` verification.

## LL-010 — GitHub Actions YAML `secrets.*` in Job `if:` & Pages Artifact Race
- **Date:** 2026-11-24 · **Domain:** CI/CD (`.github/workflows/data-pipeline.yml`, `deploy-pages.yml`)
- **Mistake:** Referencing `secrets.*` inside step/job expressions caused 0-second workflow parse errors; uploading & deploying GitHub Pages in one job caused intermittent artifact race failures.
- **Fix:** Pass secrets via `env:` + `$GITHUB_OUTPUT` and split `build` → `deploy` jobs in `deploy-pages.yml`.
- **Permanent Guardrail:** Validate all workflow YAML changes with `python3 -c "import yaml; yaml.safe_load(...)"` before commit.

## LL-011 — Backswamp Elevation Paradox & River Slope Trap
- **Date:** 2026-11-27 · **Domain:** Terrain Exposure (`alert_provider.dart`, `yala_villages.json`)
- **Mistake:** Comparing raw village MSL elevation directly to a single amphoe reference river gauge (`elev - refWater <= 0.5 / 2.5 m`) falsely alarmed Sateng backswamp villages (`14–18 m`) on normal days while misclassifying upstream mountain valleys.
- **Fix:** Implemented **3-Zone Local Terrain Exposure (`Zone A / B / C`)** using near-bank anchoring (`<= 5 km` of verified riverine station) + tambon valley-floor relative elevation, multiplied by Basin Hazard Level (Layer 1) so Basin Level 1 ALWAYS renders calm green across all terrain (`spec-unified-impact-early-warning-v5.md`).
- **Permanent Guardrail:** Parity & unit tests verify Basin Lv 1 → all zones Lv 1, Basin Lv 5 → Zone A Lv 5, Zone B Lv 4 (escalating to 5 only if overflow depth reaches Zone B), Zone C Lv 1 + formal advisory note.

## LL-012 — QA v9 Pre-Release Audit Catches (Drill-Strip Zone Parity, Guide L10n Leakage, Unverified Bank UI Guard & 5-Decimal Rounding Sliver)
- **Date:** 2026-11-27 · **Domain:** Flutter UI (`home_screen.dart`, `guide_screen.dart`, `station.dart`, `station_detail_screen.dart`, `alerts_screen.dart`), GeoJSON (`yala_village_zones.geojson`), Docs (`docs/data-provenance.md`)
- **Mistake:** Independent QA Round 1 (`audit-2026-11-27-v9-formula-v5.md`) caught 4 MEDIUM + 1 geometry LOW defects:
  1. `_DrillListStrip` in `home_screen.dart` called `elevationFloodLevel()` without forwarding `exposureZone` / `relHeightM`, leaving drill-down chips on legacy fallback while the map/sheet used Zone A/B/C.
  2. `GuideScreen` quick-call hotline buttons hardcoded Thai labels (`ปภ. 1784`, `ปภ.ยะลา`, `สพฉ. 1669`) across `en`/`zh`/`ms` locales.
  3. `Station.criticalLevel` / `watchLevel` still returned `bankLevel` (`25.128 m`) when `isDatumUnverified == true` (`FOP045`), and `station_detail_screen.dart` / `alerts_screen.dart` displayed `bankLevel` without checking `station.hasBank`.
  4. Rounding `yala_village_zones.geojson` to `dec=5` (~1.1 m grid) flipped two nearly parallel vertices on a narrow grazing sliver in `สะเตงนอก / บ้านปรามะ`, creating 1 self-intersecting ring.
  5. `docs/data-provenance.md` and `docs/lessons-learned.md` still cited draft OSM/GADM source names and older section numbers after switching to `GeoThai/boundaries`.
- **Fix:** Forwarded `exposureZone` & `relHeightM` in `_DrillListStrip`; added 4-language `_quickCallLabel()` in `guide_screen.dart`; guarded `criticalLevel`/`watchLevel` with `if (isDatumUnverified) return null;` and UI bank lines with `station.hasBank`; upgraded `yala_village_zones.geojson` rounding to `dec=6` (11 cm precision) + sliver filter (`>= 1e-9`) yielding `0` self-intersections and `0` pairwise crossings across all 468 rings; synchronized `docs/data-provenance.md` and `docs/lessons-learned.md`.
- **Permanent Guardrail:** Added automated regression tests in `backend/tests/test_pipeline.py` (zero self-intersections & zero intra-tambon edge crossings across all GeoJSON rings), `mobile/app/test/sos_and_community_test.dart` (zero Thai characters on `GuideScreen` in `en`/`zh`/`ms`), and `mobile/app/test/v1_0_1_improvements_test.dart` (`FOP045` hiding unverified `25.13 m` bank in UI + explicit `exposureZone` propagation).
