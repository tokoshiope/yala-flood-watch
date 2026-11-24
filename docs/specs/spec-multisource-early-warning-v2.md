# Spec: Multi-Source Early Flood Warning Engine (`formula_version = 2`) & iOS Prototype

- **Task ID:** P1.5-01
- **วันที่:** 2026-11-24
- **สถานะ:** Approved by Founder (Gate 1 + Gate 2 — `DEC-009`..`DEC-013`)
- **ผู้รับผิดชอบ:** Orchestrator / Dev Lead → Independent QA Reviewer

---

## 1. เป้าหมาย

ยกระดับระบบจาก "แสดงระดับน้ำปัจจุบันจาก 1 แหล่ง" เป็น **ระบบแจ้งเตือนภัยน้ำท่วมล่วงหน้า 2–12 ชั่วโมงเฉพาะจังหวัดยะลา** ที่เชื่อมฐานข้อมูลจริง 5 แหล่ง (ฟรี 100%, ไม่มี API key), มีความแม่นยำและแหล่งอ้างอิงตรวจสอบได้ทุกตัวเลข, ครอบคลุมครบทั้ง 8 อำเภอ (รวม อ.กาบัง ที่ไม่มีสถานีวัดระดับน้ำ), และมีทั้งโค้ดแอป **Flutter iOS-First** และ **Interactive iOS Simulator** ให้ทดสอบบนข้อมูลจริงและเหตุการณ์จำลองได้ทันที

---

## 2. แหล่งข้อมูลจริงทั้ง 5 แหล่ง & นโยบาย Fail-Closed

| # | Source | Endpoint | Criticality | Failure Policy |
|---|---|---|---|---|
| 1 | ThaiWater Waterlevel | `GET .../public/waterlevel?province_code=95` | **Primary** | Retry 2x (backoff 900ms), ตรวจ `result == "OK"`, deduplicate `oldcode`, fallback `left_bank_m` จาก registry, ถ้าล่ม/ว่าง/ทุกสถานี stale > 60 นาที → **FAIL-CLOSED (`exit 1`) ไม่ทับ snapshot เดิม** |
| 2 | ThaiWater Real-Time Rain | `GET .../public/rain_24h?province_code=95` | **High** | 87 สถานีฝนครบ 8 อำเภอ (ICT aware), แมตช์สถานีฝนที่ใกล้ที่สุดกับแต่ละสถานีน้ำ (Haversine) + สรุปรายอำเภอ; ถ้าล่ม → `degraded_sources: ["thaiwater_rain_24h"]` (ไม่บล็อกระดับน้ำ) |
| 3 | ThaiWater Analyst Dam | `GET .../analyst/dam` | **High** | ผสาน `dam_hourly` (กฟผ.) + `dam_daily` (ชป.) ของ **เขื่อนบางลาง** (`dam_level`, `dam_storage`, `dam_storage_percent`, `dam_inflow`, `dam_released`, `dam_spilled`); ถ้าล่ม → `degraded_sources: ["thaiwater_dam"]` |
| 4 | Open-Meteo Weather | `GET api.open-meteo.com/v1/forecast` (batch 8 amphoes) | **Standard** | คำนวณ `forecast_6h`, `forecast_24h`, `forecast_72h`, `max_prob_24h` ครบ 8 อำเภอ; ถ้าล่ม → `degraded_sources: ["open_meteo_weather"]` |
| 5 | Open-Meteo Flood (GloFAS v4) | `GET flood-api.open-meteo.com/v1/flood` (2 river checkpoints) | **Advisory** | พยากรณ์ปริมาณน้ำท่า 7 วัน (`river_discharge`, `river_discharge_mean`, `river_discharge_max`) ที่สะพานท่าสาป (ปัตตานี) และบ้านปายอยือนิ (สายบุรี); ถ้าล่ม → `degraded_sources: ["open_meteo_flood"]` |

> **หมายเหตุ Freshness Threshold:** จากการสังเกตจริง สถานีกรมชลประทาน (`ชป.`) บางแห่งรายงานรายชั่วโมง ขณะที่ `สสน.`/`กฟผ.` รายงานทุก 10–30 นาที ดังนั้นกำหนด `STATION_STALE_MINUTES = 60` สำหรับแต่ละสถานี และ fail-closed เมื่อ **ทุกสถานี** เก่าเกินเกณฑ์ (ไม่มีข้อมูลสดเหลือเลย) พร้อมแสดงอายุข้อมูล (`age_minutes`) รายสถานีอย่างโปร่งใส

---

## 3. สูตรคำนวณ `formula_version = 2` (Python ↔ Dart 100% Parity)

### 3.1 ตัวแปรย่อย (0.0 – 1.0)
- **`W` (Water Level + Rate-of-Rise `dH/dt`):**
  - มีตลิ่ง (`H_bank > 0`) และไม่ stale:
    - `H_normal = h_normal_30d` ถ้ามี, มิฉะนั้น bootstrap `H_bank - 2.0` (ตั้ง flag `h_normal_bootstrap`)
    - `W_base = clamp((H - H_normal) / (H_bank - H_normal), 0, 1)`
    - `dH = H - H_prev` (ถ้ามีค่าก่อนหน้า):
      - `dH >= 0.30` → `rise_bonus = 0.15` (flag `rapid_rise`)
      - `dH >= 0.15` → `rise_bonus = 0.08` (flag `rising_watch`)
      - else `0.0`
    - `W = clamp(W_base + rise_bonus, 0, 1)`
  - ไม่มีตลิ่ง แต่มี `situation_level` (1–4) และไม่ stale: `W = situation_level / 4.0`
  - อื่นๆ: `W = 0.0`
- **`R` (Real-Time Rainfall — 87 สถานีจริง):**
  - `R = clamp(max(rain_1h / 60.0, rain_24h / 150.0), 0, 1)`
- **`F` (24h Rainfall Forecast — Open-Meteo):**
  - `F = clamp(forecast_24h / 120.0, 0, 1)`
- **`D` (Bang Lang Dam Downstream Signal — เฉพาะอำเภอท้ายเขื่อน: บันนังสตา, กรงปินัง, เมืองยะลา):**
  - ถ้า `dam_spilled > 0` → `D = 1.0` (flag `dam_spillway_active`)
  - else ถ้า `dam_storage_percent >= 85` หรือ `dam_released_daily >= 20` → `D = 0.75`
  - else ถ้า `dam_storage_percent >= 75` หรือ `dam_released_daily >= 12` → `D = 0.45`
  - else ถ้า `dam_storage_percent >= 60` → `D = clamp((dam_storage_percent - 60) / 50, 0, 0.35)`
  - else `D = 0.0`
  - (อำเภอนอกท้ายเขื่อนบางลาง: `D = 0.0`)
- **`C` (Verified Community Reports):**
  - `C = clamp(report_count_60min / 5.0, 0, 1)` (นับเฉพาะ `trust_score >= 3`)

### 3.2 คะแนนรวมและระดับ 1–5
```text
Score = clamp(round(100.0 * (0.45*W + 0.22*R + 0.13*F + 0.10*D + 0.10*C), 1), 0.0, 100.0)
```
- `0.0 – 19.9` → **Level 1 (ปกติ)**
- `20.0 – 39.9` → **Level 2 (เฝ้าระวัง)**
- `40.0 – 59.9` → **Level 3 (เตือนภัย)**
- `60.0 – 79.9` → **Level 4 (เตือนภัยสูง)**
- `80.0 – 100.0` → **Level 5 (อันตราย — อพยพทันที)**

### 3.3 Floor, Overrides, Hysteresis & Push Gate
1. **Agency Floor:** `level = max(level_from_score(Score), clamp(situation_level, 1, 4))` (ห้ามลดระดับต่ำกว่าเกณฑ์ สสน./ชป./กฟผ.)
2. **Flash Flood Override** (บันนังสตา, กรงปินัง, เบตง, กาบัง, ธารโต):
   - `+1` ถ้า `R >= 0.70` (ฝน ≥ 42 mm/h หรือ ≥ 105 mm/24h)
   - `+1` ถ้า `C >= 0.60` (≥ 3 รายงาน/ชม.)
   - `+1` ถ้า `dH >= 0.30` ม. (น้ำขึ้นเร็ว)
   - รวมโบนัสสูงสุด `+2` และไม่เกิน Level 5
3. **Dam Spillway Early Warning Override** (บันนังสตา 2–4 ชม., กรงปินัง 4–6 ชม., เมืองยะลา 6–12 ชม.):
   - ถ้า `dam_spilled > 0` → `level = max(level, 3)` พร้อมระบุ `lead_time_hours` ชัดเจน
4. **Push Eligibility ("ฝนอย่างเดียวไม่ Push"):**
   - ต้องมี `level >= 2` **และ** อย่างน้อย 1 เงื่อนไข:
     - `W > 0` หรือ `situation_level >= 2` หรือ `D >= 0.45` หรือ `C >= 0.60`
     - หรือกรณีอำเภอ Flash Flood ที่ไม่มีสถานีวัดน้ำ (เช่น **อ.กาบัง**): `R >= 0.80` และ `F >= 0.50`
5. **Hysteresis & Cooldown (ฝั่งแอป/แจ้งเตือน):**
   - คงระดับสูงไว้ 2 ชั่วโมง (120 นาที) เมื่อคะแนนลดลง เพื่อป้องกันระดับกระพริบ
   - ไม่ส่ง Push ซ้ำระดับเดิมภายใน 30 นาที (ยกเว้นระดับเพิ่มสูงขึ้น → ส่งทันที)

---

## 4. Test Vectors บังคับ (Python & Dart ต้องได้ผลลัพธ์ตรงกัน 100%)

| ID | กรณีทดสอบ | W | dH | R | F | D | C | sit | flash | spill | Score | Final Level | Push? |
|---|---|---:|---:|---:|---:|---:|---:|---:|:--:|:--:|---:|---:|:--:|
| TV2-1 | ปกติ (น้ำ/ฝนต่ำ) | 0.10 | 0.00 | 0.10 | 0.10 | 0.00 | 0.00 | 1 | No | No | **8.0** | **1** | ❌ |
| TV2-2 | น้ำถึงตลิ่ง (`W=1`) | 1.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 3 | No | No | **45.0** | **3** | ✅ |
| TV2-3 | วิกฤตสูงสุดทุกสัญญาณ | 1.00 | 0.35 | 1.00 | 1.00 | 1.00 | 1.00 | 4 | Yes | Yes | **100.0** | **5** | ✅ |
| TV2-4 | ฝนอย่างเดียว (ไม่มีหลักฐานน้ำ) | 0.00 | 0.00 | 0.90 | 0.30 | 0.00 | 0.00 | — | No | No | **23.7** | **2** | ❌ |
| TV2-5 | เขื่อนบางลางล้น Spillway (เมืองยะลา 6–12 ชม.) | 0.20 | 0.00 | 0.20 | 0.20 | 1.00 | 0.00 | 1 | No | Yes | **26.0** | **3** (override) | ✅ |
| TV2-6 | อ.กาบัง (0 สถานีน้ำ) ฝนหนัก+พยากรณ์หนัก | 0.00 | 0.00 | 0.85 | 0.60 | 0.00 | 0.00 | — | Yes | No | **26.5** | **3** (+1 flash) | ✅ |
| TV2-7 | Flash Flood ฝนหนัก + รายงานชุมชนหนาแน่น | 0.00 | 0.00 | 0.75 | 0.00 | 0.00 | 0.60 | — | Yes | No | **22.5** | **4** (+2 flash) | ✅ |
| TV2-8 | น้ำขึ้นเร็ว `dH=0.35` (`W_base=0.50 → W=0.65`) | 0.65 | 0.35 | 0.00 | 0.00 | 0.00 | 0.00 | 2 | Yes | No | **29.3** | **3** (+1 rise) | ✅ |
| TV2-9 | ไม่มีตลิ่ง แต่ `situation_level=4` (`W=1.0`) | 1.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 4 | No | No | **45.0** | **4** (floor) | ✅ |

---

## 5. Acceptance Criteria

- [ ] AC-1: `backend/pipeline.py` ดึงข้อมูลจริงครบ 5 แหล่ง (14 สถานีน้ำ, 87 สถานีฝน, เขื่อนบางลาง, Open-Meteo 8 อำเภอ, GloFAS 2 จุด) และสร้าง `latest.json` + `manifest.json` พร้อม SHA-256 deterministic hash
- [ ] AC-2: `pytest` ผ่าน 100% ครอบคลุมทั้ง 9 Test Vectors (`TV2-1..9`), UTC/ICT timezone stale check, atomic write, registry fallback, fail-closed primary, graceful degradation secondary
- [ ] AC-3: `mobile/app` มีโฟลเดอร์ `ios/` สมบูรณ์พร้อม `Info.plist` สิทธิ์ตำแหน่ง/โทร/แผนที่, `flutter analyze` 0 issues, `flutter test` ผ่าน 100% พร้อม Formula v2 Parity Tests ตรงกับ Python ทุกเคส
- [ ] AC-4: เบอร์ฉุกเฉินทุกจุดถูกต้อง (`1784`, `073-203559`, `073-212345`, `1669`, `199`, `191`, `1677`) และ SOS มี PDPA consent + ป้ายชี้แจงชัดเจน + ปุ่มลบข้อมูลของฉันใน Settings
- [ ] AC-5: `mobile/preview/serve.py` เปิดจำลองแอป iOS บนข้อมูลจริงจาก 5 ฐานข้อมูลได้ทันที พร้อมปุ่มดึงสดและ 3 สถานการณ์จำลองน้ำท่วมล่วงหน้า
- [ ] AC-6: ผ่าน Independent QA Subagent Audit (`docs/qa/audit-2026-11-24-v2.md`) ด้วย Verdict `PASS`
