# Feature Spec: Unified Impact-Based Early Warning Framework (`formula_version = 5`)

- **Date:** 2026-11-27
- **Status:** Crystallized — Ready for Founder **Gate 2** Implementation Approval
- **Target Scope:** Yala Province (`province_code = "95"`, 8 Amphoes, 58 Subdistricts, 449 Villages, 14 Telemetry Stations)
- **Supersedes:** `docs/specs/spec-water-stage-alert-v4.md` (`formula_version = 4`)

---

## 1. Single Source of Truth: Unified 5-Level Citizen Semantics

Every screen and channel in Yala Flood Watch (Map DEM layer, Amphoe/Tambon/Village badges, User GPS/Pin card, Station detail, and Push Notifications) shares the exact same 5-level meaning:

| Level | Thai Label | Color | Citizen-Facing Meaning |
|---:|---|---|---|
| **5** | **อันตราย** | `#B71C1C` | **น้ำท่วมพื้นที่แล้ว ต้องอพยพ** |
| **4** | **เตือนภัยสูง** | `#E53935` | **พื้นที่ใกล้เคียงอยู่ระดับอันตราย หรือน้ำจ่อล้นตลิ่ง/ฝนวิกฤต ระดับน้ำอาจเพิ่มมาสูงถึงได้ พร้อมอพยพทันที** |
| **3** | **เตือนภัย** | `#EF6C00` | **มีแนวโน้มที่จะต้องอพยพภายใน 24 ชม. หรือเร็วกว่านั้น หรือกะทันหัน** |
| **2** | **เฝ้าระวัง** | `#F9A825` | **ระดับที่ต้องเริ่มเตรียมตัวพร้อมรับมือน้ำท่วม** |
| **1** | **ปกติ** | `#2E7D32` | **ต่ำกว่าระดับเฝ้าระวัง ไม่มีปัจจัยต้องรับมือ** |

---

## 2. Layer 1 — Basin & Station Hazard Engine (`compute_alert_v5` ↔ `AlertEngine.assessV5`)

### 2.1 Station Watch Threshold & Datum Calibration (`backend/registry/stations.yaml`)
1. **RID8 Official Criteria (preserved):**
   - `X.40A` บ้านท่าสาป: `watch_m = 15.50`, `critical_m = 16.50`
   - `X.77` บ้านหัวสะพาน: `watch_m = 38.00`, `critical_m = 39.70`
2. **`PAT002` เมืองยะลา (หน้าเขื่อนทดน้ำปัตตานี ต.ตาเซะ):**
   - Update `watch_m` from `12.35` → **`13.30 m`** (`mid = 13.575`, `high = 13.7125`, `critical_m = 13.85`) above normal controlled pool (`12.43–13.00 m`) to eliminate chronic dry-day Lv 2 false alarms.
3. **`FOP045` สะพานกรงปินัง (`lvl 5.79` vs `bank 25.128`, `ground 5.95`):**
   - Flag `datum_unverified: true` in `stations.yaml` & `AppConfig`.
   - Do NOT rely on `bank_m - level_msl` (`19.3 m` gap) to suppress alerts; evaluate using `dH/dt`, ThaiWater `situation_level == 5`, rain/flash-flood/dam signals, and mark `confidence = "medium"` until พพภ./สสน. verifies the gauge datum.
4. **All Other Banked Stations:** Retain `watch_m` safely above normal dry-season baseflow with `mid = (watch + crit) / 2.0`, `high = (mid + crit) / 2.0`, and `steady_band = 0.05 m`.

### 2.2 Station / Basin 5-Level Rules (Proactive Early Warning + Rain/Dam Lv 4 Gate)

Let `time_to_bank_h = (crit - level_msl) / dH` when `dH >= 0.05` and `level_msl < crit` (else `None`).

| Level | Physical Water-Stage Condition (`water_stage_level`) | Non-Water Early-Warning Condition (`early_warning_level`, max **Lv 4**) |
|---:|---|---|
| **5 — อันตราย** | `H >= crit` **or** ThaiWater `situation_level >= 5` | *(Reserved for confirmed overflow / flooding — never triggered by rain alone)* |
| **4 — เตือนภัยสูง** | • `high <= H < crit` (75%–99% of `watch → crit`)<br>• **or** `mid <= H < high` with `dH >= +0.30`<br>• **or** `H >= watch` with `time_to_bank_h <= 6.0` (projected overflow ≤ 6h) | • **Extreme Urban Pluvial (`is_urban_basin`):** (`rain_1h >= 75` or `rain_24h >= 200` or `rain_72h >= 300`) AND `api_7d >= 120` AND (`rain_1h >= 25` or `forecast_6h >= 30`)<br>• **Extreme Flash Flood (`is_flash_flood`, incl. อ.กาบัง):** same extreme rainfall + `api_7d >= 120` AND (`rain_1h >= 30` or `forecast_6h >= 25`)<br>• **Bang Lang Dam Critical Compound:** `dam_spillway_active` AND (`water_stage_level >= 2` or `inflow_daily >= 90` [D == 1.0 + extreme inflow]) |
| **3 — เตือนภัย** | • `mid <= H < high`<br>• **or** `watch <= H < mid` with `dH >= +0.15`<br>• **or** `H >= watch` with `time_to_bank_h <= 24.0` (projected overflow ≤ 24h) | • **Bang Lang Dam Spillway Active** (`spilled > 0`, downstream lead time 2–12h)<br>• **Heavy Urban Pluvial (`is_urban_basin`):** (`rain_1h >= 45` or `rain_24h >= 140` or `rain_72h >= 240`) AND (`api_7d >= 90` or `forecast_6h >= 30` or `rain_1h >= 55`)<br>• **Flash Flood Early Warning (`is_flash_flood`):** (`R >= 0.65` AND (`api_7d >= 90` or `F >= 0.50` or `C >= 0.60`)) or `R >= 0.85` |
| **2 — เฝ้าระวัง** | • `watch <= H < mid` (side way / falling / slow rise) | • **Bang Lang Dam Elevated:** `storage >= 75%` or `released >= 12` or `inflow >= 50` (`D >= 0.45`)<br>• **Flash / Urban Wet-Soil Watch:** `is_flash_flood` and (`R >= 0.65` or `C >= 0.60` or (`api_7d >= 126` and `R >= 0.45`)) |
| **1 — ปกติ** | `H < watch` (and ThaiWater `sit` in `{1, 2, 3, None}`; `sit == 4` only Lv 2 fallback for unbanked gauges) | No qualifying rain/soil/dam triggers |

- **Final Basin/Station Level:** `level = max(water_stage_level, agency_overflow_level, early_warning_level)`
- **Hysteresis & Cooldown:** Preserve **3-hour Hysteresis** and **30-minute Cooldown** end-to-end (Python `notify_fcm.py` & Dart `AlertEngine`).

---

## 3. Layer 2 — Local Terrain Exposure Engine (3 Zones across 449 Villages & Map DEM)

### 3.1 Eliminating Backswamp Confusion & River Slope Trap
Each of the 449 villages (and any user GPS/manual map pin) is classified into one of **3 permanent Terrain Exposure Zones** using **near-bank anchoring (`<= 5 km` of a verified riverine station in the same amphoe)** + **Tambon Valley-Floor relative elevation (`el - min_tambon_village_elev`)** for mountain/distant-downstream areas:

- **Zone A (Lowland / Backswamp / Valley Floor — 100 villages across all 8 amphoes):**
  - Near riverine station (`<= 5 km`): `elev <= bank + 1.5 m` (captures Sateng backswamp communities `14–18 m` like เวฬุวัน, บ้านร่ม, จารูพัฒนา, คูหามุข, สันติสุข)
  - Distant / mountain tambons: `elev - min_tambon_elev <= 5.0 m` (captures valley floor in every tambon of Betong, Than To, Kabang, Krong Pinang, Yaha, Bannang Sata, Raman)
- **Zone B (Floodplain Fringe — 66 villages across Yala):**
  - Near riverine station (`<= 5 km`): `bank + 1.5 m < elev <= bank + 5.0 m` (captures ตลาดเก่าซอย 8, หลังวัดเมืองยะลา, ห้าแยกกำปงบาโงย, จารูนอก `19–22 m`)
  - Distant / mountain tambons: `5.0 m < elev - min_tambon_elev <= 15.0 m`
- **Zone C (High Ground / Hills — 283 villages across Yala):**
  - Above Zone B thresholds (river overflow cannot reach)

### 3.2 Unified Basin Hazard × Terrain Exposure Matrix

| Basin/Amphoe Hazard Level (Layer 1) | **Zone A** (Lowland / Backswamp) | **Zone B** (Floodplain Fringe) | **Zone C** (High Ground — Option ก) |
|---:|---|---|---|
| **1 — ปกติ** | **1 — ปกติ** | **1 — ปกติ** | **1 — ปกติ** |
| **2 — เฝ้าระวัง** | **2 — เฝ้าระวัง** | **1 — ปกติ** | **1 — ปกติ** |
| **3 — เตือนภัย** | **3 — เตือนภัย** | **2 — เฝ้าระวัง** | **1 — ปกติ** + advisory note |
| **4 — เตือนภัยสูง** | **4 — เตือนภัยสูง** *(proactive before flood!)* | **3 — เตือนภัย** | **1 — ปกติ** + road/utility advisory note |
| **5 — อันตราย** | **5 — อันตราย** *(flooding now — evacuate!)* | **4 — เตือนภัยสูง** *(adjacent area at Danger!)* → escalates to **5 — อันตราย** if `overflow_depth_m >= rel_height_B` | **1 — ปกติ** + *"บ้านคุณอยู่สูงพ้นระดับน้ำแม่น้ำ แต่พื้นที่ลุ่มในอำเภออยู่ระดับอันตราย — ระวังเส้นทางสัญจร/ไฟฟ้า-ประปา"* |

*(Note: For Zone C inside steep mountain amphoes during Flash Flood Lv 4, display Lv 1 river-safe status PLUS a hillside runoff / landslide caution note.)*

### 3.3 Map DEM Layer Alignment
- Replace legacy `elevationGradientColor()` thresholds (`margin <= 0.5 / 2.5 / 6 / 12 m`) with the exact **Zone A / B / C × Basin Hazard Matrix**:
  - When `Basin Level == 1`: all terrain bands render in calm topographic green shades (no red/orange/amber false alarms).
  - As `Basin Level` rises (`2 → 3 → 4 → 5`): **Zone A** shifts color first (`amber → orange → coral red → deep red`), **Zone B** follows one tier behind (turning coral red `Lv 4` when Zone A hits `Lv 5`), and **Zone C** remains safe green.

---

## 4. Planned Implementation Scope (Awaiting Gate 2 Approval)
1. **Registry & Terrain Precomputation:** Update `backend/registry/stations.yaml` (`PAT002 watch=13.30`, `FOP045 datum_unverified=true`) and annotate all 449 villages in `backend/registry/yala_villages.json` (+ `mobile/app/assets/geo/yala_villages.json`) and `yala_elevation_zones.geojson` with `exposure_zone` (`A`/`B`/`C`) & `tambon_floor_msl`.
2. **Backend (`formula_version = 5`):** Implement `compute_alert_v5` in `backend/pipeline.py`, update `notify_fcm.py` & snapshot sync (`backend/output/` + `mobile/app/assets/snapshots/`).
3. **Mobile App (100% Parity):** Implement `AlertEngine.assessV5`, update `AppConfig` (`formulaVersion = 5`, `PAT002 watch = 13.30`, `unverifiedDatumStations = {'FOP045'}`), replace `AlertProvider.elevationFloodLevel` & `elevationGradientColor` with the Unified Zone A/B/C Matrix, and update 4-language copy in `AppStrings` (matching the Founder's exact 5-level definitions + Zone C Option ก advisory notes).
4. **Tests & Independent QA:** Full Python ↔ Dart parity test vectors (`TV5-1`..`TV5-16`) + Independent QA Audit `PASS` before Gate 3.
