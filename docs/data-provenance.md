# Yala Flood Watch — Data Provenance & Source Attribution Ledger

> **Mandatory Rule (`AGENTS.md §2.2 & §5.1`):** Every dataset, hydrological threshold, geographic boundary, elevation value, emergency phone number, evacuation center, and citizen safety instruction used in Yala Flood Watch **MUST** trace to an authoritative entry below. Any unverified datum, coordinate, or phone number MUST carry an explicit verification flag and MUST NEVER be fabricated.

*Last verified: 2026-11-27*

---

## 1. Live Telemetry & Scientific Forecast Feeds (5 Public Zero-Key Sources)

| # | Dataset | Authoritative Agency / Provider | Endpoint / Reference | Cadence | License / Terms | Verification Status |
|---|---|---|---|---|---|---|
| 1 | **Water Level Telemetry (14 Yala Stations)** | Hydro-Informatics Institute (สสน. / ThaiWater API v3), aggregating สสน., กฟผ., ชป., พพภ. | `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code=95` | 10 min (สสน./พพภ.) · 60 min (กฟผ./ชป.) | Thai Public Open Water Data | `verified` (Fail-Closed Primary) |
| 2 | **7-Day Water Level Graph History** | ThaiWater API v3 (`waterlevel_graph`) | `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel_graph` | 10 min / 60 min | Thai Public Open Water Data | `verified` |
| 3 | **Real-Time 24h Rainfall (87 Yala Gauges, all 8 Amphoes incl. Kabang)** | ThaiWater API v3 (`rain_24h`) | `https://api-v3.thaiwater.net/api/v1/thaiwater30/public/rain_24h?province_code=95` | 10–60 min | Thai Public Open Water Data | `verified` |
| 4 | **Bang Lang Dam Storage, Inflow, Release & Spillway** | ThaiWater API v3 (`analyst/dam`) — EGAT (กฟผ. hourly) + RID (ชป. daily) | `https://api-v3.thaiwater.net/api/v1/thaiwater30/analyst/dam` | Hourly (EGAT) / Daily (RID) | Thai Public Open Water Data | `verified` |
| 5 | **72h Hourly Rainfall Forecast & 7-Day Antecedent Rainfall (`API_7d`)** | Open-Meteo Weather Forecast API (ECMWF / GFS / ICON) | `https://api.open-meteo.com/v1/forecast` | Hourly | CC BY 4.0 | `verified` |
| 6 | **7-Day River Discharge Forecast (Pattani & Sai Buri Rivers)** | Open-Meteo Flood API — Copernicus GloFAS v4 | `https://flood-api.open-meteo.com/v1/flood` | Daily | CC BY 4.0 | `verified` |

---

## 2. Hydrological Thresholds & Alert Criteria (`formula_version = 5`)

| Parameter / Station | Value | Authoritative Provenance | Status |
|---|---|---|---|
| `X.40A` บ้านท่าสาป (อ.เมืองยะลา) | `watch_m = 15.50`, `critical_m = 16.50` m MSL | ศูนย์อุทกวิทยาชลประทานภาคใต้ตอนล่าง (สทภ.8 / ชป.) เกณฑ์เตือนภัยระดับน้ำ ปี 2568 (`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md`) | `verified` |
| `X.77` บ้านหัวสะพาน (อ.ธารโต) | `watch_m = 38.00`, `critical_m = 39.70` m MSL | สทภ.8 / ชป. เกณฑ์เตือนภัยระดับน้ำ ปี 2568 | `verified` |
| `X.273` บ้านปายอยือนิ (อ.รามัน) | `watch_m = 15.00`, `critical_m = 16.50` m MSL | ThaiWater bank level (`16.50 m`) + `1.50 m` freeboard watch calibration | `verified` |
| `PAT002` เมืองยะลา (หน้าเขื่อนทดน้ำปัตตานี ต.ตาเซะ) | `watch_m = 13.30`, `critical_m = 13.85` m MSL | ThaiWater bank (`13.85 m`) + calibrated above controlled weir normal pool (`12.43–13.00 m MSL`, live 7-day telemetry Nov 2026) | `verified` (Gate 2 `DEC-022`) |
| `FOP045` สะพานกรงปินัง (อ.กรงปินัง) | `left_bank = 25.128`, `ground = 5.95`, live `level ~ 5.79` | ThaiWater API v3 (`พพภ.`) — suspected local-vs-MSL datum gap (`19.3 m`) | **`datum_unverified: true`** (bypass bank-margin suppression until พพภ./สสน. confirms) |
| Other Banked Stations (`PAT001`, `BLGTD01–04`, `BLGTU02`, `MOU454`) | `critical_m = left_bank_m` (ThaiWater), `watch_m` = 1.5–2.0 m below bank | ThaiWater API v3 `station.left_bank` | `verified` |
| ThaiWater `situation_level` 1–5 Scale | `1=น้อยวิกฤต (≤10%)`, `2=น้อย (10–30%)`, `3=ปกติ (30–70%)`, `4=มาก (70–100%)`, `5=ล้นตลิ่ง (>100%)` | สสน. / ThaiWater30 API documentation & live response inspection (`DEC-021`) | `verified` |
| Bang Lang Dam Downstream Travel Time | บันนังสตา `2–4 ชม.`, กรงปินัง `4–6 ชม.`, เมืองยะลา `6–12 ชม.` | รายงานเหตุการณ์อุทกภัยลุ่มน้ำปัตตานี พ.ศ. 2567–2568 & การไฟฟ้าฝ่ายผลิตแห่งประเทศไทย (`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md`) | `verified` |
| Nov 2024 / Nov 2025 Rainfall & Inflow Benchmarks | Urban 72h rain `300+ mm` (Nov 2025: `333.8 mm`), Bang Lang inflow `>= 90 MCM/day` (Nov 2024 peak: `130.98 MCM/day`) | บทวิจัยน้ำท่วมยะลา 2567–2568 (`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md`) | `verified` |
| Hysteresis & Cooldown Windows | Hysteresis `3 hours`, Push Cooldown `30 minutes`, Steady Band `±0.05 m` | `docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md §5(ง)` + Gate 2 `DEC-021`/`DEC-022` | `verified` |

---

## 3. Geographic Boundaries & Elevation Datasets (`backend/registry/` & `mobile/app/assets/geo/`)

| File | Coverage | Authoritative Source | License | Topology / Quality Guarantee |
|---|---|---|---|---|
| `yala_subdistricts.geojson` | 58 Subdistricts (ตำบล) of Yala (`province_code=95`) | GeoThai/boundaries (`subdistricts.geojson` — DOPA-aligned curved administrative boundaries, 6,075 vertices across 58 tambons `950101`–`950802`) | Open Data (GeoThai / DOPA) | Curved natural river/ridge borders, exact shared arcs, `0` self-intersections, `0` pairwise crossings |
| `yala_amphoes.geojson` | 8 Amphoes (อำเภอ) of Yala | GeoThai/boundaries (`districts.geojson` — exact DOPA-aligned amphoe boundaries matching the 58 subdistricts) | Open Data (GeoThai / DOPA) | `0.00000%` area discrepancy vs sum of 58 subdistricts (`100%` shared borders), `0` self-intersections |
| `yala_villages.json` | 449 Villages / Communities | DOPA Thailand Administrative Divisions (`open-admin-data`) + Open-Meteo Copernicus DEM GLO-90 MSL + Zone A/B/C exposure classification | Open Data + CC BY 4.0 | Strictly inside Yala bbox (`lat 5.5–7.2`, `lon 100.5–101.9`) |
| `yala_village_zones.geojson` | 444 Village territorial zones (468 rings) inside all 58 tambons | Exact planar half-edge curved Voronoi partition of each GeoThai curved tambon around DOPA village coordinates (6-decimal precision) | Derived (exact vector) | `100.00000%` exact alignment to curved tambon boundary, `0` self-intersections, `0` pairwise crossings, zero stair-steps |
| `yala_dem_grid.json` & `yala_elevation_zones.geojson` | 1,607 DEM cells across Yala (clipped strictly to Yala boundaries) | Copernicus DEM GLO-90 via Open-Meteo Elevation API | CC BY 4.0 | Tagged with `exposure_zone` (`A`/`B`/`C`) for Unified Matrix map coloring |
| **Basemap Road/Dark Tiles (`CachingTileProvider`)** | Yala Province Light (CARTO Voyager) & Dark (CARTO Dark Matter) tiles | CARTO Basemaps / OpenStreetMap (`https://a.basemaps.cartocdn.com/...`) | CC BY 3.0 / ODbL (`© OpenStreetMap contributors · © CARTO`) | Replaces undocumented `mt1.google.com` scraping; bounded 500-tile local disk cache with offline graceful fallback |

---

## 4. Emergency Contacts, Shelters & Evacuation Guidelines (Zero-Hallucination Policy)

| Category | Entries | Authoritative Source | Verification Status |
|---|---|---|---|
| **Primary & Local Emergency Hotlines** | `1784` (ปภ. + LINE `@1784DDPM`), `073-203559` (ปภ.ยะลา), `073-212345` (ปภ.เทศบาลนครยะลา + LINE `@yalacity`), `1669` (สพฉ.), `199` (ดับเพลิง/สาธารณภัย), `191` (ตำรวจ), `073-228934` (รพ.ยะลา), `073-340141` (มทบ.46), `1677` (ร่วมด้วยช่วยกัน — อาสาสมัคร) | Official Thai agency publications; LINE/Facebook URLs live-checked HTTP 200 (`DEC-013`, `DEC-015`) | `verified` |
| **Other 7 Amphoe Direct Phone Numbers** | รามัน, ยะหา, กรงปินัง, เบตง, บันนังสตา, ธารโต, กาบัง | Pending official confirmation letter from ปภ.ยะลา (`docs/launch/ddpm-yala-verification-letter.md`) | **`pending_ddpm_verify`** (displays `073-203559` ปภ.ยะลา instead of guessing) |
| **Evacuation Shelters (City — 5 sites)** | TK Park ยะลา, รร.เทศบาล 2, รร.เทศบาล 3, มัสยิดกลาง จ.ยะลา, วัดนิโรธสังฆาราม | กรมประชาสัมพันธ์ / เทศบาลนครยะลา / สำนักงานพระพุทธศาสนาแห่งชาติ (onab.go.th) | `verified` (with call-before-travel notice) |
| **Evacuation Shelters (Outer 7 Amphoes — 7 sites)** | วัดรังสิตาวาส (รามัน) + 6 amphoe municipal/district halls | แผนเผชิญเหตุอุทกภัย จ.ยะลา & รายงานอุทกภัย พ.ศ. 2567–2568 | **`is_historical_unconfirmed: true`** (explicit badge shown in UI) |
| **Evacuation & Flood Safety Guide (`guide_screen.dart` & `web/guide.html`)** | 72-hour emergency kit, electrical/gas cutoff, flash-flood avoidance, vulnerable group priority, post-flood hygiene | คู่มือปฏิบัติตนเมื่อเกิดอุทกภัย กรมป้องกันและบรรเทาสาธารณภัย (ปภ.) กระทรวงมหาดไทย & แนวทางความปลอดภัยด้านสุขภาพในภาวะน้ำท่วม กระทรวงสาธารณสุข / สพฉ. 1669 | `verified` (standard Thai civil-defense guidance; zero invented numbers) |
