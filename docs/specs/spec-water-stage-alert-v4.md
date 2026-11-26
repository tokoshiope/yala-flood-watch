# Feature Spec: Water-Stage Primary Alert Engine (`formula_version = 4`)

- **Date:** 2026-11-27
- **Status:** Approved at Gate 2 by Founder (`DEC-021`)
- **Target Scope:** Yala Province (`province_code = "95"`, 8 Amphoes, 14 Telemetry Stations)
- **Supersedes Core Engine:** `docs/specs/spec-early-warning-v3-and-ux-v4.md` §2 (`formula_version = 3`)

---

## 1. Objectives & Gate 2 Decisions

1. **Align 5 Alert Levels 100% with Physical Water-Stage Thresholds & Trend:**
   Let `watch = watch_m` (fallback `crit - 1.5`), `crit = critical_m ?? bank_m`, `mid = (watch + crit) / 2.0`, and `high = (mid + crit) / 2.0 = watch + 0.75 * (crit - watch)`.
   Let `dH = round(level_msl - previous_msl, 4)` (when telemetry is fresh; otherwise `0.0`), with `steady_band = 0.05 m`:
   - `dH > +0.05` → `rising` (`rapid_rise` if `dH >= +0.15`, `surge` if `dH >= +0.30`)
   - `-0.05 <= dH <= +0.05` → `sideway`
   - `dH < -0.05` → `falling`

   | Level | Thai Label | Physical Water-Stage Condition (`water_stage_level`) | Color |
   |---:|---|---|---|
   | **1** | **ปกติ** | `level_msl < watch` (ต่ำกว่าเส้นเฝ้าระวัง) | `#2E7D32` |
   | **2** | **เฝ้าระวัง** | `watch <= level_msl < mid` และแนวโน้ม side way / ลดลง / ขึ้นช้า (`dH < +0.15`) | `#F9A825` |
   | **3** | **เตือนภัย** | `mid <= level_msl < high` (อยู่ที่ระดับกึ่งกลางระหว่างเส้นเฝ้าระวังและเส้นตลิ่ง, `50%–75%` ของช่วง `watch → bank`) **หรือ** `watch <= level_msl < mid` พร้อมขึ้นเร็ว (`dH >= +0.15`) | `#EF6C00` |
   | **4** | **เตือนภัยสูง** | `high <= level_msl < crit` (สูงกว่าเส้นกึ่งกลางเข้าใกล้เส้นตลิ่ง, `75%–<100%` ของช่วง `watch → bank`) **หรือ** `mid <= level_msl < high` พร้อมพุ่งขึ้นรุนแรง (`dH >= +0.30`) | `#E53935` |
   | **5** | **อันตราย** | `level_msl >= crit` (แตะหรือเลยเส้นตลิ่ง / เกณฑ์วิกฤต สทภ.8) | `#B71C1C` |

2. **Fix ThaiWater `situation_level` Misinterpretation Bug:**
   ThaiWater/HII API defines `situation_level` as a 5-step drought-to-flood capacity scale (`% storage_percent`):
   - `1` = น้อยวิกฤต (`≤10%`), `2` = น้อย (`10–30%`), `3` = ปกติ (`30–70%`), `4` = มาก (`70–100%`), `5` = ล้นตลิ่ง (`>100%`).
   - **Rule in v4:**
     - `situation_level` in `{1, 2, 3}` is **NEVER** a flood alert (`agency_overflow_level = 1`).
     - `situation_level == 5` confirms physical bank overflow → `agency_overflow_level = 5` (`flag: thaiwater_overflow_sit5`).
     - `situation_level == 4` (`น้ำมาก 70–100%`) does **NOT** override a station that has valid fresh `watch`/`crit` telemetry; it is ONLY used as a Level 2 (`เฝ้าระวัง`) fallback when a station has no `bank_m`/`critical_m` (e.g., dam/weir stations without bank thresholds).

3. **Option 1 — Non-Water Early Warning (Capped at Level 3 with Explicit Basis):**
   Rain, soil saturation (`API_7d`), forecast/GloFAS, Bang Lang Dam releases, and verified community reports remain active for early warning (especially for urban pluvial flooding in Mueang Yala / Raman / Yaha, flash-flood steep amphoes including 0-water-gauge อ.กาบัง, and Bang Lang Dam spillway releases), **capped at Level 3 (`เตือนภัย`)**:
   - **Dam Early Warning:**
     - `dam_spillway_active` (`spilled > 0`) → `early_warning_level = 3` (`dam_spillway_floor_lv3`)
     - `D >= 0.75` (`storage >= 85%` or `released >= 20` or `inflow >= 90`) → `early_warning_level = max(..., 2)` (`dam_high_flow_watch`)
   - **Urban Pluvial Early Warning (`is_urban_basin`):**
     - `(rain_1h >= 45 or rain_24h >= 140 or rain_72h >= 240)` AND `(A >= 0.50 or forecast_6h >= 30 or rain_1h >= 55)` → `early_warning_level = 3` (`urban_pluvial_override`)
   - **Flash Flood Early Warning (`is_flash_flood`):**
     - `(R >= 0.65 and (A >= 0.50 or F >= 0.50 or C >= 0.60))` or `R >= 0.85` → `early_warning_level = 3` (`flash_flood_early_warning`)
     - `R >= 0.65` or `C >= 0.60` or `(A >= 0.70 and R >= 0.45)` → `early_warning_level = max(..., 2)` (`flash_flood_watch`)
   - **Final Level:**
     `level = max(water_stage_level, agency_overflow_level, early_warning_level)`
   - **Explicit `alert_basis`:**
     - `"agency_overflow"` if `agency_overflow_level == 5` and `water_stage_level < 5`
     - `"rain_dam_early_warning"` if `level > water_stage_level` and `level == early_warning_level` (UI & push notifications clearly label *"เตือนภัยล่วงหน้าจากฝน/เขื่อน"*)
     - `"water_stage"` if `water_stage_level >= 2`
     - `"monitoring"` otherwise (`level == 1`)

4. **Preserve 3-Hour Hysteresis & 30-Minute Cooldown:**
   - Retain `hysteresisWindow = 3 hours` (both `backend/notify_fcm.py` and `AlertEngine.applyHysteresis`) and `alertCooldownWindow = 30 minutes`.

5. **Diagnostic Score (0–100) for Ranking & Telemetry:**
   Retain a deterministic diagnostic score (`0.0–100.0`, half-up 1 decimal) aligned with the 5 water bands so stations within the same alert level sort monotonically by risk:
   - `W`:
     - `H < watch`: `0.0` (strictly zero below watch line, no phantom score inflation!)
     - `watch <= H < mid`: `0.35 + 0.25 * (H - watch) / (mid - watch)` (`0.35 → 0.60`)
     - `mid <= H < high`: `0.60 + 0.20 * (H - mid) / (high - mid)` (`0.60 → 0.80`)
     - `high <= H < crit`: `0.80 + 0.20 * (H - high) / (crit - high)` (`0.80 → 1.00`)
     - `H >= crit`: `1.00`
     - Plus `rise_bonus` (only when `H >= watch`): `+0.10` if `dH >= 0.30`, `+0.05` if `dH >= 0.15`, clamped to `[0.0, 1.0]`.
     - Fallback when `crit is None` (unbanked stations): `1.0` if `situation_level == 5`, `0.35` if `situation_level == 4`, else `0.0`.
   - `raw = 0.50 * W + 0.18 * R + 0.08 * A + 0.10 * F + 0.08 * D + 0.06 * C`
   - `score = clamp(round_half_up_1(100.0 * raw), 0.0, 100.0)`
   - Note: `level` is governed by `max(water_stage_level, agency_overflow_level, early_warning_level)`, NOT by raw `score` thresholds, preventing light/moderate rain below the watch line from flipping Level 1 to Level 2.

6. **Push Eligibility (`should_push`):**
   `should_push = (level >= 2) and has_primary_signal`, where `has_primary_signal` is true if any of:
   - `water_stage_level >= 2`
   - `agency_overflow_level >= 5` (or unbanked `situation_level == 4`)
   - `dam_spillway_active` or `D >= 0.75`
   - `urban_pluvial_triggered`
   - `C >= 0.60`
   - `is_flash_flood` and `early_warning_level >= 2` and (`not has_water_gauge` or `R >= 0.65` with `A >= 0.50 or F >= 0.50` or `C >= 0.60`)

---

## 2. Exact Parity Test Vectors (`TV4-1`–`TV4-12`, Python ↔ Dart 100%)

| ID | Scenario | Inputs (`watch`/`crit`/`lvl`/`prev`/`sit`/rain/dam) | Expected `water_stage_level` | Expected `level` | Expected `alert_basis` | `should_push` |
|---|---|---|---:|---:|---|:-:|
| **TV4-1** | Normal below watch + ThaiWater `sit=3` (ปกติ 40%) | `BLGTD03` `watch=15.80, crit=17.29, lvl=12.59, prev=12.64, sit=3` | 1 | **1** (ปกติ) | `monitoring` | ❌ |
| **TV4-2** | Normal below watch + ThaiWater `sit=4` (มาก 87%) | `PAT001` `watch=36.80, crit=38.678, lvl=36.01, prev=36.00, sit=4` | 1 | **1** (ปกติ) | `monitoring` | ❌ |
| **TV4-3** | At watch + sideway (`PAT002` live case) | `PAT002` `watch=12.35, crit=13.85, lvl=12.43, prev=12.43, sit=4` | 2 | **2** (เฝ้าระวัง) | `water_stage` | ✅ |
| **TV4-4** | At watch + rapid rise (`dH=+0.20`) | `X.40A` `watch=15.50, crit=16.50, lvl=15.70, prev=15.50` | 3 | **3** (เตือนภัย) | `water_stage` | ✅ |
| **TV4-5** | At midpoint (`mid=16.00`) + rising (`dH=+0.10`) | `X.40A` `watch=15.50, crit=16.50, lvl=16.05, prev=15.95` | 3 | **3** (เตือนภัย) | `water_stage` | ✅ |
| **TV4-6** | Above midpoint, nearly at bank (`high=16.25 <= 16.35 < 16.50`) | `X.40A` `watch=15.50, crit=16.50, lvl=16.35, prev=16.30` | 4 | **4** (เตือนภัยสูง) | `water_stage` | ✅ |
| **TV4-7** | Over bank (`>= 16.50`) with `sit=None` | `X.40A` `watch=15.50, crit=16.50, lvl=16.52, prev=16.40, sit=None` | 5 | **5** (อันตราย) | `water_stage` | ✅ |
| **TV4-8** | RID8 `X.77` critical (`39.70 < left_bank 40.30`) | `X.77` `watch=38.00, crit=39.70, bank=40.30, lvl=39.75, prev=39.60` | 5 | **5** (อันตราย) | `water_stage` | ✅ |
| **TV4-9** | Urban Pluvial early warning (capped Lv 3, river `< watch`) | Mueang Yala `watch=15.50, crit=16.50, lvl=14.20, rain24=155, rain72=333.8, api7d=120, is_urban=True` | 1 | **3** (เตือนภัย) | `rain_dam_early_warning` | ✅ |
| **TV4-10** | Bang Lang Dam spillway active (capped Lv 3, river `< watch`) | `watch=15.50, crit=16.50, lvl=13.50, dam_signal=1.0, dam_spillway=True` | 1 | **3** (เตือนภัย) | `rain_dam_early_warning` | ✅ |
| **TV4-11** | Kabang 0-water-gauge severe flash flood rain (capped Lv 3) | `has_water_gauge=False, is_flash=True, rain1h=51, api7d=110, f24=72` | 1 | **3** (เตือนภัย) | `rain_dam_early_warning` | ✅ |
| **TV4-12** | ThaiWater `situation_level == 5` overflow confirmation (stale/unbanked) | `lvl=None, bank=None, sit=5` | 1 | **5** (อันตราย) | `agency_overflow` | ✅ |
