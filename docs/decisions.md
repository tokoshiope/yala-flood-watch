# Decisions Log (Living File)

## DEC-001 — ขอบเขตภูมิศาสตร์: เฉพาะจังหวัดยะลาก่อน
- **วันที่:** 2026-11-23
- **สถานะ:** ยืนยันแล้วโดย Founder
- **ตัดสินใจ:** MVP แรกเฉพาะ จ.ยะลา (8 อำเภอเป้าหมาย: เมืองยะลา รามัน ยะหา กรงปินัง เบตง บันนังสตา ธารโต กาบัง) ขยายภาคใต้ต่อใน Phase 6
- **เหตุผล:** ข้อมูลยะลาครบ (14 สถานีวัดระดับน้ำ + 87 สถานีฝน), มีภัยจริง (พ.ย. 2568), ทดสอบและวัดผลได้เร็ว
- **กระทบ:** ทุกเอกสาร baseline, dashboard, wireframe, tasks

## DEC-002 — โมเดลราคา: ฟรีทั้งหมด ไม่มี IAP
- **วันที่:** 2026-11-23
- **สถานะ:** ยืนยันแล้วโดย Founder
- **ตัดสินใจ:** ไม่มี paywall/IAP/subscription ตามคำร้องขอของ Founder (แอพสาธารณประโยชน์)
- **เหตุผล:** ผู้ใช้คือประชาชนในพื้นที่เสี่ยง; เสนอต่อทุนจากภาครัฐ/มูลนิธิ/ESG
- **กระทบ:** ตัดส่วน Billing/IAP ออกจาก roadmap ทั้งหมด

## DEC-003 — สูตรคะแนนเตือนภัย v1 (Superseded by DEC-012)
- **วันที่:** 2026-11-23
- **สถานะ:** Superseded by `DEC-012` (`formula_version = 2`)
- **ตัดสินใจ:** `Score = 0.5×W + 0.25×R + 0.15×F + 0.10×C` ระดับ 1–5
- **เหตุผล:** ออกแบบก่อนพบ ThaiWater `analyst/dam` (เขื่อนบางลาง) และ `rain_24h` (87 สถานี)

## DEC-004 — Tech Stack (Confirmed in DEC-006 & DEC-010)
- **วันที่:** 2026-11-23
- **สถานะ:** ยืนยันแล้ว (คง Flutter iOS-First)

## DEC-005 — โครงสร้าง Repository มาตรฐาน (Superseded by DEC-009)
- **วันที่:** 2026-11-23
- **สถานะ:** Superseded by `DEC-009`

## DEC-006 — Gate 1 & Gate 2 รอบแรก (2026-11-23)
- **ตัดสินใจ:** Founder อนุมัติ MVP เฉพาะยะลา, ฟรีทั้งหมด, คง Flutter, pipeline snapshot/CDN + FCM

## DEC-007 — Dynamic Registry แยกจาก API
- **วันที่:** 2026-11-23
- **สถานะ:** ยืนยันแล้ว (ขยายใน Phase 1.5 เพิ่ม `amphoes.yaml`)
- **ตัดสินใจ:** แยก `stations.yaml`, `amphoes.yaml`, `contacts.yaml`, `shelters.yaml` เป็นแหล่งความจริงใน repo และแนบเข้า snapshot

## DEC-008 — Fail-Closed + MAX_STALE_MINUTES
- **วันที่:** 2026-11-23
- **สถานะ:** ยืนยันแล้ว
- **ตัดสินใจ:** pipeline exit(1) และไม่เขียนทับ snapshot เดิมเมื่อ Primary ThaiWater waterlevel ว่าง/ล่ม/ทุกสถานีเก่าเกินเกณฑ์ หรือพิกัดนอกขอบเขตยะลา

## DEC-009 — ย้าย Workspace พัฒนาหลักมาที่ `/Users/tokyo/Documents/Yala Flood` และอัปเกรด Charter v2.0
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (Gate 1+2)
- **ตัดสินใจ:** คัดลอกโปรเจกต์พร้อม git history มาพัฒนาต่อที่ `/Users/tokyo/Documents/Yala Flood` โดยคง `/Users/tokyo/Documents/yala-flood-app` เป็นสำรองที่ไม่ถูกแก้ไข และอัปเกรด `AGENTS.md` / `README.md` เป็น **Life-Safety Hybrid Pragmatic 5-Agent Charter v2.0** (เทียบเท่า/เหนือกว่า `GPF Project` และ `EV in 1`)
- **เหตุผล:** รักษาสำรองเดิมปลอดภัย 100% และยกระดับมาตรฐานความปลอดภัยด้านข้อมูลภัยพิบัติ (Zero-Hallucination Emergency Data, Multi-Source Attribution, Simulation Replay Harness)
- **กระทบ:** `AGENTS.md`, `README.md`, `docs/tasks.md`

## DEC-010 — สถาปัตยกรรม iOS-First: คง Flutter (`mobile/app/ios/`) + Interactive iOS Preview Server
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (มอบอำนาจ Chief Architect พิจารณาแนวทางที่เสถียรที่สุด)
- **ตัดสินใจ:** ใช้ **Flutter iOS-First** โดยสร้างโฟลเดอร์ `mobile/app/ios/` (พร้อม `Info.plist` สิทธิ์ตำแหน่ง/โทร/แผนที่สำหรับ Xcode 27.2) คู่กับ **Interactive iOS Simulator Preview** (`mobile/preview/serve.py`) ที่ดึงฐานข้อมูลจริง 5 แหล่ง + โหมดจำลองภัยพิบัติ
- **เหตุผล:** (1) เครื่องพัฒนาติดตั้ง Flutter 3.50.1 และ Xcode 27.2 พร้อมอยู่แล้ว ไม่มี Node.js (2) โค้ด Flutter เดิมมีโครงสร้างแผนที่ OSM/แคช/Provider/30+ tests ที่ดีอยู่แล้ว ประหยัดเวลาและเสถียรกว่าเขียนใหม่ทั้งหมด (3) รองรับต่อยอด Android ในอนาคตโดยไม่เพิ่มต้นทุนสถาปัตยกรรม
- **กระทบ:** `mobile/app/ios/`, `mobile/app/lib/`, `mobile/preview/`

## DEC-011 — เชื่อมต่อฐานข้อมูลสาธารณะจริง 5 แหล่ง (ฟรี 100% ไม่ต้องใช้ API Key)
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (Gate 2)
- **ตัดสินใจ:** เชื่อมต่อ 5 แหล่งข้อมูลจริงที่ผ่านการทดสอบ Live Probe แล้ว:
  1. ThaiWater `public/waterlevel?province_code=95` (14 สถานีวัดระดับน้ำ)
  2. ThaiWater `public/rain_24h?province_code=95` (87 สถานีฝนจริง ครบทั้ง 8 อำเภอรวม อ.กาบัง)
  3. ThaiWater `analyst/dam` (เขื่อนบางลาง กฟผ. รายชั่วโมง + กรมชลประทาน รายวัน)
  4. Open-Meteo Weather Forecast (`CC BY 4.0`, พยากรณ์ฝน 24–72 ชม. ทั้ง 8 อำเภอ)
  5. Open-Meteo Flood / GloFAS v4 (`CC BY 4.0`, พยากรณ์ปริมาณน้ำท่า 7 วัน ลุ่มน้ำปัตตานี & สายบุรี)
- **เหตุผล:** ทำให้ตัวแปร `W`, `R`, `F`, `D` ทำงานด้วยข้อมูลจริงทั้งหมดทันที ปิดจุดบอด อ.กาบัง (0 สถานีวัดน้ำแต่มี 4 สถานีฝน) และให้ Lead-Time เตือนภัยล่วงหน้าได้จริงโดยต้นทุน ฿0
- **กระทบ:** `backend/pipeline.py`, `backend/registry/amphoes.yaml`, `docs/02-data-discovery-report.md`

## DEC-012 — อัปเกรดสูตรแจ้งเตือนล่วงหน้าเป็น `formula_version = 2`
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (Gate 2)
- **ตัดสินใจ:**
  - สูตรหลัก: `Score = clamp(round(100 * (0.45*W + 0.22*R + 0.13*F + 0.10*D + 0.10*C), 1), 0, 100)`
  - `W` รวมโบนัสอัตราการขึ้นของน้ำ (`dH/dt >= 0.30 ม./รอบ` → +0.15, `>= 0.15 ม./รอบ` → +0.08, clamp 0..1)
  - `R = clamp(max(rain_1h / 60, rain_24h / 150), 0, 1)` จาก 87 สถานีฝนจริง
  - `F = clamp(forecast_24h / 120, 0, 1)` จาก Open-Meteo รายอำเภอ
  - `D` = สัญญาณเขื่อนบางลางสำหรับอำเภอท้ายเขื่อน (บันนังสตา 2–4 ชม., กรงปินัง 4–6 ชม., เมืองยะลา 6–12 ชม.): `dam_spilled > 0` → `D = 1.0` + บังคับขั้นต่ำ Level 3 (เตือนภัยล่วงหน้า); `storage >= 85%` หรือ `release >= 20 MCM/day` → `D = 0.75`; `storage >= 75%` หรือ `release >= 12 MCM/day` → `D = 0.45`; นอกนั้น scale ตามสัดส่วน (อำเภอนอกท้ายเขื่อน `D = 0`)
  - `C = clamp(report_count_60min / 5, 0, 1)`
  - Flash Flood Override (บันนังสตา, กรงปินัง, เบตง, กาบัง, ธารโต): `R >= 0.7` (+1), `C >= 0.6` (+1), `dH/dt >= 0.30` (+1) รวมสูงสุด +2 ไม่เกิน Level 5
  - กฎกัน False Alarm ("ฝนอย่างเดียวไม่ Push"): Push เมื่อ Level ≥ 2 และมีสัญญาณหลัก (`W > 0` หรือ `situation_level >= 2` หรือ `D >= 0.45` หรือ `C >= 0.6` หรือกรณีเขต Flash Flood ที่ไม่มีสถานีวัดน้ำเช่น กาบัง เมื่อ `R >= 0.8` ร่วมกับ `F >= 0.5`)
- **เหตุผล:** สะท้อนกายภาพจริงของลุ่มน้ำปัตตานี–สายบุรี แจ้งเตือนล่วงหน้าได้ 2–12 ชม. ก่อนน้ำล้นตลิ่ง พร้อมควบคุม False Alarm
- **กระทบ:** `backend/pipeline.py`, `mobile/app/lib/services/alert_engine.dart`, `docs/04-core-methodology.md`, `docs/specs/spec-multisource-early-warning-v2.md`

## DEC-013 — แก้ไขเบอร์โทรศัพท์ฉุกเฉินและมาตรฐานข้อมูลศูนย์พักพิง (Zero-Hallucination Rule)
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (Gate 2)
- **ตัดสินใจ:** แก้ไขข้อผิดพลาดที่ระบุ `1677` เป็นกรม ปภ. → เปลี่ยนเป็นข้อมูลที่ตรวจสอบยืนยันแล้ว: **1784** (สายด่วนนิรภัย กรม ปภ. + LINE `@1784DDPM`), **073-203559** (สำนักงาน ปภ.ยะลา 073-203559–64), **073-212345** (ปภ.เทศบาลนครยะลา 24 ชม.), **1669** (เจ็บป่วยฉุกเฉิน สพฉ.), **199** (ดับเพลิง/ภัยพิบัติ), **191** (ตำรวจ), **073-340141** (ศูนย์บรรเทาสาธารณภัย มทบ.46), **073-228934** (รพ.ยะลา), **1677** (ร่วมด้วยช่วยกัน) และติดป้ายสถานะ `verified` / `pending_ddpm_verify` บนจุดพักพิงทุกแห่ง
- **เหตุผล:** ป้องกันความเข้าใจผิดในสถานการณ์วิกฤตชีวิต
- **กระทบ:** `backend/registry/contacts.yaml`, `backend/registry/shelters.yaml`, `mobile/app/lib/config/app_config.dart`, `mobile/app/lib/screens/sos_screen.dart`, `mobile/app/lib/screens/shelters_screen.dart`

## DEC-014 — Google Maps Foundation + GeoJSON 8 อำเภอ + เวลาไทย UTC+7 + 4 ภาษา + Phase 2 Cloud Bridge
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder
- **ตัดสินใจ:**
  1. ใช้ **Google Maps** เป็นแผนที่ฐานหลักพร้อมขอบเขตจริง 8 อำเภอ จ.ยะลา (`yala_amphoes.geojson`, 13.9 KB) ระบายสีตามระดับแจ้งเตือน 1–5 และใช้ Google Maps Directions URL (Free SKU) นำทางไปยัง **ศูนย์พักพิง**
  2. แสดงเวลาอัปเดตทุกจุดเป็น **เวลาประเทศไทย (UTC+7)** อย่างชัดเจน และปรับกราฟพยากรณ์ฝนรายชั่วโมงเป็นแถบเลื่อนลงมาพร้อมช่องเวลา (UTC+7)
  3. รองรับเมนูเลือกภาษา **4 ภาษา** (`ไทย`, `English`, `中文`, `Bahasa Melayu`) ทั้งใน iOS Prototype และ Flutter App
  4. ดำเนิน **Phase 2 Cloud Bridge**: สร้าง Supabase Schema + RLS + PDPA 90-day retention (`supabase/migrations/0001_initial_yala_flood_schema.sql`), Atomic CDN Publisher (`backend/publish_supabase.py`), Flutter `SnapshotService` (CDN + Offline Asset), และหน้า Legal Web PDPA/Terms (`web/` + GitHub Pages workflow)
- **กระทบ:** `backend/registry/yala_amphoes.geojson`, `backend/publish_supabase.py`, `supabase/migrations/`, `web/`, `mobile/preview/`, `mobile/app/lib/`
