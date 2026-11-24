# Feature Spec: Early Warning Engine v3 (Research-Calibrated) & UX v4 (Dark Mode, Curved GIS, DEM Gradient, GPS/Pin, Full 4-Language)

- **Date:** 2026-11-24
- **Status:** Implementing (Founder-Requested 8-Point Overhaul)
- **Research Reference:** `docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md`
- **Target Scope:** Yala Province (`province_code = "95"`, 8 Amphoes, 58 Subdistricts, 449 Villages)

---

## 1. Comparative Audit: Research Paper vs Current `formula_version = 2`

| มิติการเตือนภัย | `formula_version = 2` เดิม | ช่องว่างที่พบจากบทวิจัย (พ.ย. 2567 & พ.ย. 2568) | การอัปเกรดเป็น `formula_version = 3` |
|---|---|---|---|
| **เกณฑ์ระดับน้ำรายสถานี** | ใช้ `h_normal = bank - 2.0` แบบเหมาจ่ายทุกสถานี | สทภ.8 (2568) กำหนดเกณฑ์เฝ้าระวัง/วิกฤตจริง (X.40A: `15.50 / 16.50 ม.`, X.77: `38.00 / 39.70 ม.`) และสถานี ชป. (`X.40A`, `X.273`, `X.77`) ส่ง `situation_level = null` ทำให้ตอนน้ำล้นตลิ่ง `+1.24 ม.` อาจได้แค่ Level 3 | เพิ่ม `watch_m` / `critical_m` รายสถานีใน `stations.yaml` + **Physical Bank-Overflow Override** (`>= critical_m` → ขั้นต่ำ Lv 4, `>= critical_m + 0.50` → ขั้นต่ำ Lv 5, `>= watch_m` & `dH >= 0.15` → ขั้นต่ำ Lv 3) |
| **ช่วงเวลาฝน & ความชื้นดิน** | ดูเฉพาะ `rain_1h` และ `rain_24h` | พ.ย. 2568 เมืองยะลาฝนสะสม 3 วัน `333.8 มม.` รามัน `216.4 มม.` ทำให้ท่วมแม้อ่างบางลางแค่ 57%; ดินอิ่มน้ำทำให้น้ำหลากเร็วกว่าปกติ | เพิ่มฝนสะสมหลายช่วงเวลา (`R1/R24/R72`) + **Antecedent Precipitation Index (`API_7d`, τ=4 วัน)** จาก Open-Meteo `past_days=7` (ฟรี 0 key) |
| **กลไกน้ำท่วม 4 แบบ** | แยกเฉพาะ `flash` vs `riverine` | บทวิจัย §1 แยกชัด 4 กลไก: น้ำป่าลาดเขา, ล้นตลิ่งปัตตานี, ล้นตลิ่งสายบุรี/คลองยะหา, **น้ำท่วมขังเขตเมือง** (ซึ่งเกิดก่อนน้ำแม่น้ำถึงตลิ่ง) | เพิ่ม **Urban Pluvial Override** (เมืองยะลา/รามัน/ยะหา เมื่อ `R1>=45` หรือ `R24>=140` หรือ `R72>=240` ร่วมกับ `API>=0.50` หรือ `forecast_6h>=30` → Lv 3 + Push ได้) และระบุ `flood_mechanism` |
| **เขื่อนบางลาง (`D`)** | ดู `spilled`, `storage >= 75/85%`, `released >= 12/20` | ปี 2567 น้ำไหลเข้าเขื่อนพุ่ง `130.98 ล้าน ลบ.ม./วัน` แม้อ่างเริ่มที่ 51%; ปี 2568 อ่าง 57% แต่เมืองท่วม | เพิ่มสัญญาณ `inflow_daily_mcm` (`>= 50` → `D >= 0.45`, `>= 90` → `D >= 0.70`) โดยคงการไม่พึ่งเขื่อนเป็นตัวชี้วัดหลักของฝนใต้เขื่อน |
| **พยากรณ์น้ำท่า GloFAS v4** | ดึงมาใน snapshot แต่ไม่ได้รวมในสูตร | บทวิจัย §4.4 แนะนำใช้พยากรณ์หลายช่วงเวลา + ensemble/ความน่าจะเป็น | รวม `forecast_6h/24h/72h` × `prob` และโบนัส `glofas_peak_ratio` (`>= 2.0` → +0.15, `>= 3.0` → +0.25) เข้าในสัญญาณ `F` |
| **เซนเซอร์ขาด/ล่ม** | สถานีฝน stale/missing คืน `0.0` | บทวิจัย §7 ย้ำกรณี อ.รามัน 27 พ.ย. 2568: ห้ามแปลค่าขาดเป็นฝนศูนย์ | Fallback ไปยังสถานีใกล้เคียง (<25 กม.) หรือ Open-Meteo observed 24h + ติด flag `rain_sensor_gap` และส่งออก `confidence` (`high`/`medium`/`low`) |
| **Hysteresis ลดระดับ** | 2 ชั่วโมง | บทวิจัย §5(ง) แนะนำ 3–6 ชม. และระดับน้ำต่ำกว่าเกณฑ์ ≥ 0.2–0.3 ม. | อัปเกรด `hysteresisWindow` เป็น **3 ชั่วโมง** ทั้ง `pipeline/notify_fcm.py` และ `AlertEngine` |

---

## 2. Formula v3 Exact Mathematical Specification (100% Python ↔ Dart Parity)

```
Score = clamp(round_half_up_1(100 * (
    0.38 * W +
    0.22 * R +
    0.10 * A +
    0.12 * F +
    0.10 * D +
    0.08 * C
)), 0.0, 100.0)
```

### Signal Definitions (all clamped `[0.0, 1.0]`):
1. **`W` (River Stage + Rate-of-Rise `dH/dt`):**
   - If `critical_m` (or `bank_m`) and `level_msl` are present and fresh:
     - `watch = watch_m ?? (critical - 1.5)`
     - `base_low = watch - 1.5` (or `h_normal_30d` if provided)
     - Piece-wise impact curve:
       - `level <= base_low` → `w_base = 0.0`
       - `base_low < level < watch` → `0.55 * (level - base_low) / (watch - base_low)`
       - `watch <= level < critical` → `0.55 + 0.45 * (level - watch) / (critical - watch)`
       - `level >= critical` → `1.0`
     - `rise_bonus`: `+0.15` if `dH >= 0.30`, `+0.08` if `dH >= 0.15`, else `0.0`
     - `W = clamp(w_base + rise_bonus, 0, 1)`
   - Else if `situation_level` in `1..4`: `W = clamp(situation_level / 4.0, 0, 1)`
   - Else: `W = 0.0`
2. **`R` (Multi-Window Observed Rain):**
   - `R = clamp(max(rain_1h / 60.0, rain_24h / 150.0, rain_72h / 260.0), 0, 1)`
3. **`A` (Antecedent Wetness — 7-Day API):**
   - `API_7d = Σ_{i=0..6} P_{t-i} * exp(-i / 4.0)` (from Open-Meteo `past_days=7` daily precip, fallback `rain_24h` if degraded)
   - `A = clamp(api_7d_mm / 180.0, 0, 1)`
4. **`F` (Multi-Window Forecast + GloFAS Discharge Ratio):**
   - `f_rain = max(forecast_6h / 50.0, forecast_24h / 110.0, forecast_72h / 200.0)`
   - `glofas_bonus = 0.25 if ratio >= 3.0 else (0.15 if ratio >= 2.0 else 0.0)`
   - `F = clamp(f_rain + glofas_bonus, 0, 1)`
5. **`D` (Bang Lang Dam Downstream Signal):**
   - Applies to downstream amphoes (`บันนังสตา`, `กรงปินัง`, `เมืองยะลา`)
   - `spilled > 0` → `1.0` (`spillway_active = True`)
   - `storage >= 85%` or `released_daily >= 20` or `inflow_daily >= 90` → `0.75`
   - `storage >= 75%` or `released_daily >= 12` or `inflow_daily >= 50` → `0.45`
   - `storage >= 60%` → `clamp((storage - 60) / 50, 0, 0.35)`
6. **`C` (Verified Community Reports, `trust >= 3`):**
   - `C = clamp(reports_60m / 5.0, 0, 1)`

### Physical & Mechanism Overrides:
1. **Agency Floor:** `level = max(score_level, clamp(situation_level, 1, 4))`
2. **Physical Bank-Overflow Override (Fresh water telemetry):**
   - `level_msl >= critical + 0.50` → `level = max(level, 5)` (`bank_overflow_severe`)
   - `level_msl >= critical` → `level = max(level, 4)` (`bank_overflow`)
   - `level_msl >= watch` and `dH >= 0.15` → `level = max(level, 3)` (`watch_rapid_rise`)
3. **Flash Flood Override (`is_flash_flood = True`):**
   - `+1` each for (`R >= 0.65`), (`C >= 0.60`), (`dH >= 0.30`), or (`A >= 0.70 and R >= 0.45`), capped at `+2`, max Level 5.
4. **Urban Pluvial Override (`is_urban_basin = True`: เมืองยะลา, รามัน, ยะหา):**
   - When (`rain_1h >= 45` or `rain_24h >= 140` or `rain_72h >= 240`) AND (`A >= 0.50` or `forecast_6h >= 30` or `rain_1h >= 55`): `level = max(level, 3)` (`urban_pluvial_override`)
5. **Dam Spillway Override:**
   - `dam_spillway_active` → `level = max(level, 3)` (`dam_spillway_floor_lv3`)

### Push Eligibility:
- `should_push = (level >= 2) and has_primary_signal`
- `has_primary_signal` is true if any of:
  - `W > 0.0` (or physical bank/watch override)
  - `situation_level >= 2`
  - `D >= 0.45`
  - `C >= 0.60`
  - `urban_pluvial_override`
  - `is_flash_flood and not has_water_gauge and R >= 0.70 and (A >= 0.50 or F >= 0.50)`

---

## 3. UX v4 Specifications (Items 2–8)

1. **iOS Dark Mode Contrast Overhaul:** Theme-aware map label pills (`#0F172A` surface + crisp `#FFFFFF` text in dark mode; `#FFFFFF` surface + `#0F172A` text in light mode), theme-aware breadcrumb/strip/banners/headers/charts, and brightness-adjusted alert level display colors across all 6 screens.
2. **True Curved Administrative & Village Boundaries:** Replace coarse 15-vertex subdistrict polygons with high-resolution curved official ADM2/ADM3 boundaries for all 8 amphoes and 58 subdistricts, plus smooth organic terrain-clipped village zones inside each subdistrict.
3. **Real Station Names on Map Pins:** Display human-readable station names (`บ้านปายอยือนิ`, `บ้านท่าสาป`, `บ้านหัวสะพาน`, etc.) localized in all 4 languages instead of raw station codes (`X.273`).
4. **Alert Level Explanation Guide in Settings:** Color-coded 1–5 alert level legend with clear triggers and recommended actions in all 4 languages, plus MSL elevation map color explanation.
5. **Continuous DEM Elevation-Graded Map Layer:** Precompute real Copernicus DEM topographic contour bands (`yala_elevation_zones.geojson`) across Yala Province and color dynamically against live river water levels (MSL) for genuine valley-to-mountain color gradation.
6. **User GPS & Manual Map Pin + Hyper-Local Elevation/Alert Comparison:** PDPA-consented GPS (`When In Use` only) + long-press/button manual pin drop, point-in-polygon amphoe/tambon detection, offline bilinear DEM ground elevation (`yala_dem_grid.json`), nearest station comparison, `+/- m` height margin, and personalized alert level card (wiped cleanly by PDPA delete).
7. **Complete 4-Language Localization (`th` / `en` / `zh` / `ms`):** Zero remaining hardcoded Thai strings when English, Chinese, or Malay is selected across all tabs, dialogs, stations, shelters, contacts, SOS types/statuses, alerts, and map sheets.
