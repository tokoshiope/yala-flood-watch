# Yala Flood Watch — Task Board (Living File)

> อัปเดตอัตโนมัติทุกครั้งที่จบงานตาม `AGENTS.md §2` · Status: `TODO` / `IN PROGRESS` / `IN QA` / `WAITING FOUNDER` / `DONE` / `BLOCKED`

---

## Phase 0 — Inception & Baseline Docs `[DONE]`
- [x] A. Prototype Dashboard + Wireframe 14 จอ + PRD 1,011 บรรทัด — DONE (2026-11-23)
- [x] B. เอกสารฐาน `docs/01`–`04` + Living Files — DONE (2026-11-23)
- [x] C. Gate 1 + Gate 2 รอบแรก (DEC-006) — DONE (2026-11-23)

## Phase 1 — Multi-Source Data Foundation & Formula v2 `[DONE]`
- [x] คัดลอกโปรเจกต์มาพัฒนาต่อที่ `/Users/tokyo/Documents/Yala Flood` (คง `yala-flood-app` เป็นสำรอง) — DONE (2026-11-24 · `DEC-009`)
- [x] อัปเกรด `AGENTS.md` และ `README.md` เป็น **Life-Safety Hybrid 5-Agent Charter v2.0** (เหนือกว่าต้นแบบ GPF/EV in 1) — DONE (2026-11-24)
- [x] แก้ไขเบอร์ฉุกเฉินวิกฤต (`1784` ปภ., `073-203559` ปภ.ยะลา, `073-212345` เทศบาลนครยะลา, `1669`, `199`, `191`, แยก `1677` ร่วมด้วยช่วยกัน) และระบุสถานะยืนยันศูนย์พักพิงใน `backend/registry/` — DONE (2026-11-24 · `DEC-013`)
- [x] สร้างทะเบียน 8 อำเภอ `backend/registry/amphoes.yaml` พร้อมระยะเวลาน้ำเดินทางจากเขื่อนบางลาง — DONE (2026-11-24)
- [x] อัปเกรด `backend/pipeline.py` เชื่อมต่อ **5 ฐานข้อมูลจริง (ฟรี 0 API key)**: ThaiWater Waterlevel (14), Rain 24h (87 ครบ 8 อำเภอ), Bang Lang Dam (กฟผ.+ชป.), Open-Meteo Weather 72h, Open-Meteo GloFAS v4 7 วัน — DONE (2026-11-24 · Live verified `stations=14 rain_gauges=87 amphoes=8 degraded=0`)
- [x] Implement สูตร `formula_version = 2` + Fail-Closed + Atomic Write + Registry Fallback + Deterministic Hash — DONE (2026-11-24 · `pytest 23/23 passed` ใน sandbox ออฟไลน์)
- [x] อัปเดต `.github/workflows/data-pipeline.yml` (CI pytest + unique artifact run_id + concurrency) — DONE (2026-11-24)

## Phase 1.5 — iOS-First Flutter App Core & Interactive Prototype `[DONE]`
- [x] สร้างโฟลเดอร์ iOS จริง (`mobile/app/ios/Runner.xcworkspace`) + ตั้งค่า `Info.plist` (ชื่อไทย, `NSLocationWhenInUseUsageDescription`, `LSApplicationQueriesSchemes`, `yalaflood://`) — DONE (2026-11-24 · `DEC-010`)
- [x] ซ่อมและอัปเกรด `mobile/app/lib/services/alert_engine.dart` ให้ตรงสูตร `formula_version = 2` (100% Python ↔ Dart Parity, TV2-1..TV2-10, Hysteresis 2 ชม., Cooldown 30 นาที) — DONE (2026-11-24 · `flutter analyze 0 issues`, `flutter test 43/43 passed`)
- [x] เชื่อม `NotificationService.showFloodAlert` เข้า `AlertProvider` + เพิ่ม PDPA GPS Consent Dialog ใน `SosScreen` + ปุ่ม "ลบข้อมูลทั้งหมดของฉัน (PDPA)" ใน `SettingsScreen` + แก้เบอร์ 1784/073-203559/073-212345/191 — DONE (2026-11-24)
- [x] สร้าง Interactive iOS Prototype & Live Simulation Server (`mobile/preview/serve.py` + `index.html`) เชื่อม 5 ฐานข้อมูลจริง + 3 เหตุการณ์จำลองน้ำท่วมล่วงหน้า + อัปเกรด `tools/dashboard/index.html` — DONE (2026-11-24)
- [x] **Independent QA / Hydrology / Security Audit (Context แยก)** + แก้ไขทุก BLOCKER/HIGH/MEDIUM (`docs/qa/audit-2026-11-24-v2.md`) — DONE (2026-11-24 · พบ 2 BLOCKER + 3 HIGH → แก้ครบและผ่าน `pytest 23/23` + `flutter test 43/43`)

## Phase 2 — Cloud Bridge, UX v2 (Google Maps / 4 Languages), Legal Web `[DONE — Code & Dry-Run Ready]`
- [x] เพิ่มขอบเขตภูมิศาสตร์จริง 8 อำเภอ (`backend/registry/yala_amphoes.geojson` + `mobile/app/assets/geo/`) และระบายสีระดับแจ้งเตือน 1–5 บนแผนที่ฐาน Google Maps — DONE (2026-11-24 · `DEC-014`)
- [x] แสดงเวลาอัปเดตประเทศไทย (UTC+7) ทุกจุด, เปลี่ยน "จุดพักพิง" → **"ศูนย์พักพิง"** + นำทางด้วย Google Maps, ปรับกราฟพยากรณ์ฝนเป็นแถบเลื่อนลงมาพร้อมช่องเวลาชัดเจน และเพิ่มเมนู **4 ภาษา (ไทย/อังกฤษ/จีน/มาเลเซีย)** — DONE (2026-11-24)
- [x] สร้าง Supabase Schema + RLS + Rate-Limited RPC + PDPA 90-day Purge (`supabase/migrations/0001_initial_yala_flood_schema.sql`) — DONE (2026-11-24)
- [x] สร้าง Atomic Immutable Supabase CDN Publisher (`backend/publish_supabase.py` + Dry-Run & Tamper Fail-Closed tests) และเชื่อมเข้า `.github/workflows/data-pipeline.yml` — DONE (2026-11-24)
- [x] เพิ่ม Flutter `SnapshotService` (`mobile/app/lib/services/snapshot_service.dart`) อ่าน 5-Source Snapshot จาก Supabase CDN / Bundled Offline Asset + โหลด 8-Amphoe GeoJSON — DONE (2026-11-24)
- [x] สร้าง Legal Web (`web/index.html`, `web/privacy.html` PDPA, `web/terms.html` Life-Safety Disclaimer) + `.github/workflows/deploy-pages.yml` + `docs/launch/phase2-cloud-setup-runbook.md` — DONE (2026-11-24)
- [x] **UX v3 & Data Precision Overhaul (11 รายการจาก Founder):** ชื่อแอป `แจ้งเตือนน้ำท่วมยะลา`, กรอบเขื่อนบางลางด้านบน, แผนที่เฉพาะยะลา 3 ระดับความสูง (`8 อำเภอ → 58 ตำบล → 449 หมู่บ้าน` ด้วย Copernicus DEM MSL), ย้ายข้อมูลไปแถบ `ข้อมูล`, ศูนย์พักพิงอ้างอิงข้อมูลเดิม 8 อำเภอ + เอาป้าย "พิกัดโดยประมาณ" ออก, เพิ่มลิงก์ LINE/Facebook ที่ตรวจสอบ HTTP 200 แล้ว, ซ่อนคำเทคนิค `formula v2`, และแยกสวิตช์เสียงแจ้งเตือน/ข้อความ Notification — DONE (2026-11-24 · `DEC-015` · `pytest 27/27 passed`, `flutter analyze 0 issues`, `flutter test 45/45 passed`)
- [ ] Founder ตั้งค่า Supabase Project / GitHub Secrets / GitHub Pages ตาม `docs/launch/phase2-cloud-setup-runbook.md` — WAITING FOUNDER
- [ ] ขอพิกัดศูนย์พักพิงรายตำบลและเบอร์ตรงที่ว่าการอำเภออีก 7 อำเภอจาก ปภ.ยะลา (`pending_ddpm_verify` → `verified`) — WAITING FOUNDER

## Phase 3 — iOS TestFlight Beta & APNs/FCM Push `[TODO]`
- [ ] ตั้งค่า `GoogleService-Info.plist` + APNs Key + Firebase Cloud Messaging topic รายอำเภอ (`yala_flood:{amphoe}`)
- [ ] ทดสอบ Build ลงเครื่อง iPhone จริงผ่าน Xcode / TestFlight (Offline mode, Local+Remote Push, Dynamic Type ผู้สูงอายุ)
- [ ] เพิ่มรองรับภาษามลายูท้องถิ่น (Yawi/Malay) สำหรับประกาศเตือนภัยหลัก

## Phase 4 — Gate 3 Release Sign-Off & App Store Launch `[TODO]`
- [ ] ผ่าน Independent QA Re-Audit (`PASS`) + Founder Gate 3 Sign-Off
- [ ] ส่ง Apple App Store Review (ฟรี 100% ไม่คิดค่าบริการ)
