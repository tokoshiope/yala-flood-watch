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

## DEC-015 — UX v3 สำหรับประชาชน: แผนที่เฉพาะยะลา 3 ระดับความสูง (อำเภอ→ตำบล→หมู่บ้าน), ย้ายข้อมูลไปแถบ "ข้อมูล", ศูนย์พักพิงอ้างอิงเดิม, ลิงก์ LINE/Facebook ที่ตรวจสอบ HTTP 200 แล้ว, และซ่อนภาษาเทคนิค
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder
- **ตัดสินใจ:**
  1. เปลี่ยนชื่อแถบหัวบนสุดและชื่อแอปเป็น **`แจ้งเตือนน้ำท่วมยะลา`**, เปลี่ยนแถบ 1 เป็น **`แผนที่`**, และย้ายกรอบ **เขื่อนบางลาง** ขึ้นมาด้านบนต่อจากแถบหัวเรื่อง
  2. แผนที่ Google Maps แสดง **เฉพาะเขต จ.ยะลา** (Mask พื้นที่นอกจังหวัด + ล็อกขอบเขต) พร้อมข้อมูลจริง **8 อำเภอ → 58 ตำบล (`yala_subdistricts.geojson`) → 449 หมู่บ้าน (`yala_villages.json`, DOPA)** เสริมความสูงภูมิประเทศจริงจาก Open-Meteo Copernicus DEM (MSL) เพื่อระบายสีระดับน้ำท่วมถึงตามความสูงพื้นที่เทียบระดับน้ำแม่น้ำ และกดขยาย/ย้อนกลับได้ครบทั้ง 3 ระดับ
  3. ย้ายกราฟพยากรณ์ฝนรายชั่วโมง (UTC+7), สรุป 8 อำเภอ และรายการสถานี 14 แห่งไปรวมที่แถบ 2 เปลี่ยนชื่อเป็น **`ข้อมูล`**
  4. สืบค้นและรวบรวมศูนย์พักพิงที่เคยใช้รับผู้ประสบภัยน้ำท่วม จ.ยะลา (พ.ศ. 2567–2568) ครบทั้ง 8 อำเภอ (เช่น วัดนิโรธสังฆาราม ต.สะเตง, วัดรังสิตาวาส ต.กายูบอเกาะ อ.รามัน, อาคารอเนกประสงค์/หอประชุมอีก 6 อำเภอ) โดยเอาป้าย `"ชื่อทางการ (พิกัดโดยประมาณ)"` ออก และติดป้าย **`อ้างอิงจากข้อมูลเดิม รอยืนยัน`** สำหรับศูนย์ต่างอำเภอ
  5. เพิ่มช่องทาง **LINE** และ **Facebook** ที่ตรวจสอบการเข้าถึงจริง (`HTTP 200 OK`) ใน `contacts.yaml` v3, iOS Prototype และ `SosScreen` (`@1784DDPM`, `@yalacity`, `facebook.com/DDPMNews`, `thainems`, `pryalahospital`, `ruamduay`) โดยตัดลิงก์ที่ไม่ตอบสนอง (`niems.go.th` timeout, `disaster.go.th` 403) ออก
  6. ซ่อนศัพท์เทคนิค (`formula_version`, สูตร `W/R/F/D/C`, คะแนนดิบ, `SHA-256`, `Degraded`) ออกจากหน้าจอประชาชน ขณะยังคงตรรกะ `formula_version = 2` และชุดทดสอบ parity เบื้องหลัง 100%
  7. เพิ่มสวิตช์แยกในหน้าตั้งค่า: **เปิด/ปิดเสียงแจ้งเตือน** (`!quietMode`) และ **เปิด/ปิดข้อความ Notification** (`pushEnabled`)
- **กระทบ:** `backend/registry/yala_subdistricts.geojson`, `backend/registry/yala_villages.json`, `backend/registry/contacts.yaml`, `backend/registry/shelters.yaml`, `mobile/preview/serve.py`, `mobile/preview/index.html`, `mobile/app/ios/Runner/Info.plist`, `mobile/app/lib/`, `mobile/app/assets/geo/`, `web/`

## DEC-016 — ปิดงานวิศวกรรม Phase 3 & 4 Pre-Release ครบทุกชิ้น (iOS App Store Readiness, FCM Topic Engine, Privacy Manifest, Launch Kit และ Independent QA `PASS`)
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติโดย Founder (แยกดำเนินงานคู่ขนาน Track 1 Founder / Track 2 AI Team) · Independent QA **`PASS`** (`docs/qa/audit-2026-11-24-v3-pre-release.md`)
- **ตัดสินใจ:**
  1. **iOS App Store Readiness:** สร้างไอคอนแอปจริง 15 ขนาด (No-Alpha, `1024×1024` ผ่าน `sips`), สร้างและลงทะเบียน `PrivacyInfo.xcprivacy` ใน `Runner.xcodeproj/project.pbxproj` (`plutil -lint OK`), เพิ่ม `ITSAppUsesNonExemptEncryption=false` และ `UIBackgroundModes=[remote-notification]`, และจัดให้ Bundle ID (`net.yala.floodapp`) และเวอร์ชัน (`0.4.0+4`) ตรงกันทุกไฟล์
  2. **FCM Topic Push รายอำเภอ (ASCII Standard):** จัดทำระบบติดตามหัวข้อ `yala_flood_all` + 8 อำเภอ (`yala_flood_<slug>`) ตรงกัน 100% ระหว่าง `mobile/app/lib/services/notification_service.dart` และ `backend/notify_fcm.py` (รองรับ Cooldown 30 นาที, หมดอายุ Hysteresis 2 ชม., Escalation ทันที, เก็บสถานะข้ามรอบด้วย `actions/cache@v4`, และ Fail-Closed เมื่อ SHA-256 ไม่ตรง) พร้อมรองรับการปิดเสียงจริงบน iOS/Android

## DEC-017 — Pre-TestFlight Lean, Stability, iOS APNs & Security Hardening + Independent QA v4 `PASS`
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ ผ่าน Independent QA Re-Audit **`PASS`** (`docs/qa/audit-2026-11-24-v4-testflight-hardening.md`)
- **ตัดสินใจ:** ก่อนอัปโหลดบิลด์ `0.4.0+4` ขึ้น Apple TestFlight ได้ปรับจูนความลีน เสถียรภาพบน iPhone จริง และความปลอดภัยครบทุกจุด:
  1. **iOS Push Reliability & Lean Topic Sync:** รอ APNs Token บน iOS/macOS แบบมีเพดาน (6s) ก่อนเปิด `_pushConfigured` และ subscribe topic, ฟัง `onRegistered` เพื่อ re-sync อัตโนมัติ, ย้าย `initializePush` เป็น non-blocking หลังเปิดหน้าจอ, และบันทึกหัวข้อใน `SharedPreferences` ลดการยิง FCM ซ้ำตอนเปิดแอปจาก 9 ครั้ง → 0 ครั้ง
  2. **Lean Startup & Lifecycle Refresh:** ยกเลิกการโหลด CDN ซ้ำ 2 รอบตอนเปิดแอป (`hydrate()` โหลด 3 ชั้นแผนที่ + แคช/Bundled แบบขนาน แล้วค่อย `refresh()` 1 ครั้ง), เชื่อม `WidgetsBindingObserver` รีเฟรชเมื่อกลับมาเปิดแอปตาม `settings.refreshMinutes`, และปิด HTTP client ใน `dispose()`
  3. **Client Security & PDPA Completeness:** บังคับ `https://` บน CDN + ดึง `manifest.json` และ `latest.json` ขนานพร้อม `utf8.decode`, ตรวจขอบเขตพิกัดยะลา (`5.5–7.2`, `100.5–101.9`) + กัน `TypeError`/`NaN` แบบ Fail-Closed, ตั้ง GPS timeout 15 วินาที, sanitize เบอร์ `tel:`, บังคับ `https` บนลิงก์ภายนอก, และลบ `subscribedTopicPrefsKey` ใน `LocalStore.deleteAllUserData()`
  4. **Xcode Signing & Production IPA:** สร้าง `Runner.entitlements` (`aps-environment`), ผูก `GoogleService-Info.plist`, ตั้ง Automatic Signing (`4884CSRPSY`), และสร้าง Release IPA ชี้ไปที่ Supabase CDN จริง (`https://ibrdiroqzgqykxpttafj.supabase.co/storage/v1/object/public/snapshots`) ผ่าน `pytest 28/28`, `flutter analyze 0 issues`, `flutter test 50/50`
- **กระทบ:** `mobile/app/lib/main.dart`, `mobile/app/lib/config/app_config.dart`, `mobile/app/lib/services/notification_service.dart`, `mobile/app/lib/services/snapshot_service.dart`, `mobile/app/lib/services/thai_water_service.dart`, `mobile/app/lib/services/local_store.dart`, `mobile/app/lib/state/alert_provider.dart`, `mobile/app/lib/screens/sos_screen.dart`, `mobile/app/lib/screens/shelters_screen.dart`, `mobile/app/test/security_and_hardening_test.dart`, `mobile/app/ios/Runner/Runner.entitlements`, `mobile/app/ios/Runner.xcodeproj/project.pbxproj`
  3. **Accessibility & Fail-Closed Client Cache:** เพิ่ม `largeTextMode` (โหมดตัวอักษรใหญ่ผู้สูงอายุ) + 4-language `Locale` binding ใน `main.dart`, อัปเกรด `SnapshotService` ให้ตรวจ `manifest.json` `content_hash` + `province.code == '95'` และแคช Snapshot ที่ผ่านการตรวจในเครื่อง (`AppConfig.cacheSnapshotKey`), และจำกัด `community_reports` RLS ไม่ให้เปิดเผย `device_hash` (สร้าง `public_community_reports` view)
  4. **CI/CD & Founder Launch Kit:** เพิ่ม `.github/workflows/ci.yml`, สคริปต์ `mobile/app/scripts/release_preflight.sh`, และชุดเอกสารพร้อมใช้ (`docs/launch/founder-action-guide.md`, `docs/launch/app-store-metadata.md`, `docs/launch/ddpm-yala-verification-letter.md`)
- **กระทบ:** `mobile/app/ios/`, `mobile/app/lib/`, `mobile/app/scripts/`, `backend/notify_fcm.py`, `supabase/migrations/`, `.github/workflows/`, `docs/launch/`, `docs/qa/`

## DEC-018 — อัปเกรดสูตรเตือนภัย `formula_version = 3` (อิงบทวิจัยน้ำท่วมยะลา 2567–2568) และ UX v4 ครบ 8 รายการ (Dark Mode, ขอบเขตเว้าโค้ง GADM 4.1, ชั้นสีไล่ระดับความสูง DEM, ป้ายชื่อสถานีจริง, หมุด/GPS ผู้ใช้, คำอธิบายระดับแจ้งเตือน และแปลครบ 4 ภาษา)
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ ผ่าน Independent QA Re-Audit **`PASS`** (`docs/qa/audit-2026-11-24-v5-formula3-ux4.md`) · บิลด์ `0.5.0+5` · ผ่าน `pytest 42/42`, `flutter analyze 0 issues`, `flutter test 66/66`
- **ตัดสินใจ:**
  1. **อัปเกรดสูตรเตือนภัยเป็น `formula_version = 3` (Python ↔ Dart Parity 100%):** สังเคราะห์จาก `docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md` เพิ่มเกณฑ์ระดับน้ำรายสถานี สทภ.8 ปี 2568 (`X.40A: 15.50/16.50 ม.`, `X.77: 38.00/39.70 ม.`, `X.273: 15.00/16.50 ม.`), น้ำหนัก 6 สัญญาณ (`0.38W + 0.22R + 0.10A + 0.12F + 0.10D + 0.08C`), ฝนสะสมหลายช่วงเวลา (`R1/R24/R72`), ความชื้นดินสะสม `API_7d` จาก Open-Meteo `past_days=7`, โบนัส GloFAS v4, สัญญาณน้ำไหลเข้าเขื่อนบางลาง (`inflow_daily >= 50/90 MCM`), Physical Bank-Overflow Override (แก้ช่องโหว่ พ.ย. 2568 ที่ ชป. ไม่มี `situation_level`), Urban Pluvial Override (เมืองยะลา/รามัน/ยะหา ฝน 3 วัน 333.8 มม. แม้อ่างบางลาง 57%), Sensor-Gap Fallback + ระดับความเชื่อมั่น (`confidence`), และขยาย Hysteresis เป็น 3 ชม.
  2. **แก้ไข iOS Dark Mode Contrast ครบทุกหน้าจอและแผนที่:** ปรับป้ายชื่ออำเภอ/ตำบล/หมู่บ้าน/สถานีบนแผนที่ให้ใช้พื้นหลัง `#0F172A` + ตัวอักษรขาวในโหมดมืด และพื้นขาว + ตัวอักษร `#0F172A` ในโหมดสว่าง พร้อมปรับสีข้อความ/แบนเนอร์/กราฟ `_LevelTrendPainter`/การ์ดในทุกแท็บให้ผ่านเกณฑ์คอนทราสต์ชัดเจน
  3. **เส้นขอบเว้าโค้งจริงตามพื้นที่อ้างอิง:** เปลี่ยนขอบเขต 8 อำเภอ (เฉลี่ย 140 จุด/อำเภอ) และ 58 ตำบล (เฉลี่ย 42.2 จุด/ตำบล สูงสุด 181 จุด) เป็นขอบเขตเว้าโค้งความละเอียดสูงจาก GADM 4.1 พร้อมสร้างโซนหมู่บ้านเว้าโค้งตามภูมิประเทศ (`yala_village_zones.geojson`, 422 โซน) ภายในขอบเขตตำบลจริง
  4. **ป้ายสถานีชื่อจริง:** ปรับ `StationMarker` แสดงชื่อสถานีจริง (เช่น `บ้านปายอยือนิ` แทนรหัส `X.273`) รองรับทั้ง 4 ภาษา
  5. **คำอธิบายระดับการแจ้งเตือน 1–5 ในแถบตั้งค่า:** เพิ่มการ์ดอธิบายความหมาย สี เกณฑ์ และวิธีปฏิบัติตัวครบทั้ง 5 ระดับ พร้อมคำอธิบายชั้นสีไล่ระดับความสูงบนแผนที่
  6. **Layer สีไล่ระดับจริงตามค่าความสูงภูมิประเทศ (ม.รทก.):** เก็บข้อมูล Copernicus DEM ครบ 100% (`1,607/1,607` เซลล์ในยะลา) สร้าง `yala_elevation_zones.geojson` (356 โซนความสูง) และ `yala_dem_grid.json` ระบายสีไล่ระดับจริงจากที่ราบลุ่มริมแม่น้ำถึงภูเขาเทียบระดับน้ำแม่น้ำล่าสุด
  7. **พิกัด GPS เครื่องผู้ใช้ & ปักหมุดบนแผนที่:** เพิ่มปุ่ม "ตำแหน่งของฉัน" (ขอ PDPA Consent ก่อนทุกครั้ง) และโหมดปักหมุด/กดค้างบนแผนที่ คำนวณอำเภอ/ตำบล, ความสูงพื้นที่จริง (ม.รทก.) แบบออฟไลน์, สถานีใกล้สุด, ส่วนต่างความสูงกับระดับน้ำ (`+/- ม.`) และระดับแจ้งเตือนเฉพาะจุด (ลบออกทั้งหมดเมื่อกดลบข้อมูล PDPA)
  8. **แปลครบ 4 ภาษาเต็มรูปแบบ (`th`/`en`/`zh`/`ms`):** แปลข้อความ UI, ป้ายชื่อสถานี 14 แห่ง, 8 อำเภอ, ตำบล/หมู่บ้าน, 12 ศูนย์พักพิง, 9 ช่องทางฉุกเฉิน, ระดับแจ้งเตือน 1–5, ประเภท/สถานะ SOS, แบนเนอร์ และกราฟครบทุกหน้าจอ
- **กระทบ:** `backend/pipeline.py`, `backend/notify_fcm.py`, `backend/registry/stations.yaml`, `backend/registry/yala_*.geojson`, `backend/registry/yala_dem_grid.json`, `backend/tests/test_pipeline.py`, `mobile/app/assets/geo/`, `mobile/app/assets/snapshots/`, `mobile/app/lib/`, `mobile/app/test/`, `docs/specs/spec-early-warning-v3-and-ux-v4.md`

## DEC-019 — ปลดล็อคส่ง SOS จริง (ทางเลือก C — Hybrid v1.0): Smart SOS Dispatch แบบ Zero-Server PII + รายงานจุดน้ำท่วมชุมชน Tier C (Supabase RLS + PDPA 90 วัน)
- **วันที่:** 2026-11-24
- **สถานะ:** ✅ อนุมัติ Gate 2 โดย Founder · ผ่าน Independent QA Re-Audit **`PASS`** (`docs/qa/audit-2026-11-24-v6-sos-option-c.md`) · เวอร์ชัน `1.0.0+7` · ผ่าน `pytest 47/47`, `flutter analyze 0 issues`, `flutter test 77/77`, `plutil -lint OK`
- **ตัดสินใจ:**
  1. **ปลดล็อค Smart Real SOS Dispatch (Zero-Server PII):** เปลี่ยนหน้า SOS จากบันทึกในเครื่องอย่างเดียวเป็นการสร้างชุดข้อความ SOS ครบถ้วน (ประเภทเหตุ, พิกัด GPS ±ความแม่นยำ, ลิงก์ Google Maps, อำเภอ/ตำบล/ความสูงพื้นที่ MSL เทียบระดับน้ำจากข้อมูลออฟไลน์, เบอร์โทร และรายละเอียดเพิ่มเติม) ส่งออกจริงทันทีผ่าน **SMS (`sms:?body=` เข้ารหัส `%20` ปลอดบั๊ก `+` บน iOS ใช้ได้แม้เน็ตล่ม)**, **LINE Share (`https://line.me/R/share`)**, **คัดลอก+เปิด LINE ทางการ (`@1784DDPM`, `@yalacity`)** และ **โทรด่วน (`1784` / `073-203559` / `1669`)** พร้อมแถบยืนยันสถานะแบบติดขอบบนใน Modal Sheet และเก็บประวัติ/เบอร์โทรไว้ในเครื่องเท่านั้น
  2. **เปิดใช้รายงานสถานการณ์น้ำชุมชน (Tier C — Anonymous Supabase RPC):** เชื่อมต่อ `submit_community_report` และวิว `public_community_reports` ใน Supabase Schema เดิม (ปัดเศษพิกัด ~110 ม. ทศนิยม 3 ตำแหน่ง, รหัส `device_hash` SHA-256 64 ตัวอักษรจาก Salt ในเครื่องที่ลบทิ้งได้ในปุ่ม PDPA, ไม่ส่งชื่อ/เบอร์โทร, จำกัด 1 ครั้ง/ชม., ลบอัตโนมัติใน 90 วัน, และ Fail-Closed เมื่อไม่ได้ตั้งค่า `YALA_SUPABASE_ANON_KEY`)
  3. **เชื่อม Tier C เข้า Backend Pipeline + PDPA Purge อัตโนมัติ:** เพิ่ม `fetch_community_reports_60m()` ใน `backend/pipeline.py` (กรองเฉพาะ `trust_score >= 3` และอำเภอในยะลาเท่านั้น · degrade อย่างปลอดภัยหาก Supabase ไม่ตอบ · ไม่สามารถเป็นเงื่อนไขเดียวในการสั่ง Level 5) และเรียก `purge_expired_reports` RPC อัตโนมัติหลังอัปโหลด Snapshot ใน `backend/publish_supabase.py` พร้อมบังคับ `https://` ก่อนส่ง `SUPABASE_SERVICE_ROLE_KEY`
  4. **สอดคล้อง App Store & PDPA 100%:** เพิ่ม `sms` ใน `Info.plist`, เพิ่ม `CoarseLocation` + `OtherUserContent` (ไม่ผูกตัวตน/ไม่ติดตาม) ใน `PrivacyInfo.xcprivacy`, อัปเดต `web/privacy.html` และ `docs/launch/app-store-metadata.md` (พร้อม URL GitHub Pages จริง) และปรับเวอร์ชันเป็น `1.0.0+7` พร้อมส่งขึ้น Apple App Store
- **กระทบ:** `docs/specs/spec-sos-dispatch-and-community-reports.md`, `mobile/app/lib/services/sos_dispatch_service.dart`, `mobile/app/lib/services/community_report_service.dart`, `mobile/app/lib/screens/sos_screen.dart`, `mobile/app/lib/state/alert_provider.dart`, `mobile/app/lib/config/app_config.dart`, `mobile/app/lib/services/local_store.dart`, `mobile/app/lib/models/sos_request.dart`, `mobile/app/lib/l10n/app_strings.dart`, `mobile/app/ios/Runner/Info.plist`, `mobile/app/ios/Runner/PrivacyInfo.xcprivacy`, `mobile/app/pubspec.yaml`, `mobile/app/scripts/release_preflight.sh`, `mobile/app/test/sos_and_community_test.dart`, `mobile/app/test/security_and_hardening_test.dart`, `backend/pipeline.py`, `backend/publish_supabase.py`, `backend/tests/test_pipeline.py`, `.github/workflows/data-pipeline.yml`, `web/privacy.html`, `docs/launch/app-store-metadata.md`

## DEC-020 — ปรับปรุงแอป v1.0.1+8 ครบ 6 รายการ (ไอคอนแบบที่ 2, ตัด SOS/UGC 100%, กราฟแท่งฝนแนว iOS Weather, ระยะเหลือถึงตลิ่ง + กราฟย้อนหลัง 7 วัน + อัปเดตทุก 10 นาที, เตือนชัดเจนระดับหมู่บ้าน/ตำบล, ปุ่มโทรศูนย์พักพิงแสดงเบอร์) + ชุดตอบกลับ Apple Guideline 2.1
- **วันที่:** 2026-11-26
- **สถานะ:** ✅ Founder อนุมัติ Gate 1 & 2 (เลือกไอคอนแบบที่ 2 + ยืนยันตัด SOS & Community Report UGC ออกทั้งหมด) · ผ่าน Independent QA Re-Audit v7 **`PASS`** (`docs/qa/audit-2026-11-26-v7-appstore-polish.md`) · ผ่าน `pytest 51/51`, `flutter analyze 0 issues`, `flutter test 84/84`, `plutil -lint OK` · รอ Founder อนุมัติ **Gate 3**
- **ตัดสินใจ:**
  1. **เปลี่ยนไอคอนแอปเป็นแบบที่ 2 (Modernized Reference — "YALA FLOOD" + กระดิ่งเตือนภัย + บ้านสีขาว + คลื่นน้ำท่วม):** สร้างครบทั้ง 15 ขนาดใน `AppIcon.appiconset` (ยืนยัน RGB No-Alpha 100%) รวมถึง `design/app-icon-1024.png` และ `web/icon-512.png`
  2. **ตัดฟีเจอร์ส่งข้อความ SOS และรายงานจุดน้ำท่วมชุมชน (UGC) ออกทั้งหมด (0% UGC · 0% Server PII):** หน้าฉุกเฉินคงเฉพาะแบนเนอร์คำเตือนความปลอดภัยและช่องทางติดต่อทางการที่ยืนยันแล้ว (เบอร์โทร 9 ช่องทาง + LINE + Facebook), หยุดการดึง `fetchRecentReports()` บน `AlertProvider`, ปรับ `Info.plist` (ตัด `sms` และคำอ้าง SOS), ปรับ `PrivacyInfo.xcprivacy` เป็น `NSPrivacyCollectedDataTypes = []` ให้ตรง 100% กับ App Store Connect **"Data Not Collected"**, และอัปเดต `web/privacy.html` + `docs/launch/app-store-metadata.md` (พร้อมคำตอบครบ 6 ข้อตาม Apple Guideline 2.1 และสคริปต์อัดวิดีโอบน iPhone จริง)
  3. **กราฟแท่งพยากรณ์ฝนรายชั่วโมงแนว iOS Weather:** เปลี่ยน `_RainForecastCard` เป็นกราฟแท่งแนวตั้งมุมมนเลื่อนซ้าย-ขวาได้ 24 ชม. พร้อมแกน Y (มม.), ป้าย % โอกาสฝนตก, แตะดูค่ารายชั่วโมง, สีข้อความผ่าน WCAG AA ทั้ง Light/Dark Mode และรองรับจอแคบ 375pt + โหมดตัวอักษรใหญ่ 1.35× โดยไม่ล้น
  4. **สถานีวัดระดับน้ำเน้น "ระยะเหลือถึงตลิ่ง" + กราฟแนวโน้มย้อนหลัง 7 วัน + อัปเดตความละเอียดสูงทุก 10 นาที:**
     - ยืนยันความถี่จริงจาก ThaiWater API v3: **สสน./พพภ. อัปเดตทุก 10 นาที**, **กฟผ./ชป. อัปเดตทุก 1 ชม.** และเชื่อมต่อ Public API `waterlevel_graph` ฟรีเพื่อดึงข้อมูลย้อนหลัง 7 วันเต็มความละเอียด (10 นาที / 1 ชม.)
     - อัปเกรด GitHub Actions Pipeline จากทุก 15 นาที → **ทุก 10 นาที (`*/10 * * * *`)**, ลด CDN `max-age` ของ `latest.json` เหลือ 120 วินาที, และแนบ `history_7d` สำรองใน Snapshot ให้ดูกราฟ 7 วันแบบออฟไลน์ได้ทันที
     - หน้า `AlertsScreen` และ `StationDetailScreen` แสดง **ระยะเหลือถึงตลิ่ง** เป็นตัวเลขหลักตัวใหญ่ พร้อมป้ายความถี่อัปเดตจริง และกราฟโต้ตอบได้ (สลับ `24 ชม.` / `3 วัน` / `7 วัน` + แตะลากดูค่ารายจุด + เส้นประตลิ่ง/เฝ้าระวัง)
  5. **สถานการณ์รายละเอียดระบุชื่อหมู่บ้านและตำบลชัดเจน:** เพิ่ม `watch_areas` ใน `backend/pipeline.py` และ `watchVillagesForAmphoe()` / `watchVillagesNearStation()` ใน `AlertProvider` เพื่อแสดงชื่อหมู่บ้าน (ม.XX) และตำบลที่มีความเสี่ยง/พื้นที่ลุ่มต่ำบนการ์ดสถานการณ์ 8 อำเภอ (รวม อ.กาบัง), การ์ดแจ้งเตือน และหน้าสถานี ครบ 4 ภาษา
  6. **ปุ่มโทรศูนย์พักพิงแสดงเบอร์โทรชัดเจน:** เปลี่ยนข้อความปุ่มเป็น `กดโทร 073-212345` / `กดโทร 073-203559` (รองรับ EN/ZH/MS พร้อม `FittedBox` ป้องกันข้อความตัดขาด)
- **กระทบ:** `backend/pipeline.py`, `backend/publish_supabase.py`, `backend/tests/test_pipeline.py`, `.github/workflows/data-pipeline.yml`, `design/app-icon-1024.png`, `web/icon-512.png`, `web/privacy.html`, `docs/launch/app-store-metadata.md`, `docs/specs/spec-v1-0-1-appstore-polish.md`, `docs/qa/audit-2026-11-26-v7-appstore-polish.md`, `mobile/app/pubspec.yaml`, `mobile/app/ios/Runner/Info.plist`, `mobile/app/ios/Runner/PrivacyInfo.xcprivacy`, `mobile/app/ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `mobile/app/assets/snapshots/`, `mobile/app/lib/config/app_config.dart`, `mobile/app/lib/l10n/app_strings.dart`, `mobile/app/lib/models/station.dart`, `mobile/app/lib/models/flood_snapshot.dart`, `mobile/app/lib/services/thai_water_service.dart`, `mobile/app/lib/state/alert_provider.dart`, `mobile/app/lib/screens/alerts_screen.dart`, `mobile/app/lib/screens/station_detail_screen.dart`, `mobile/app/lib/screens/sos_screen.dart`, `mobile/app/lib/screens/shelters_screen.dart`, `mobile/app/lib/screens/app_shell.dart`, `mobile/app/test/app_smoke_test.dart`, `mobile/app/test/sos_and_community_test.dart`, `mobile/app/test/v1_0_1_improvements_test.dart`
