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
- [x] แก้ไข GitHub Actions 2 จุดหลัง Push จริงขึ้น `tokoshiope/yala-flood-watch`: แยก job `build` → `deploy` ใน `.github/workflows/deploy-pages.yml` (แก้ race condition `No artifacts named "github-pages" were found`) และย้ายการเช็ก `secrets.*` ใน `.github/workflows/data-pipeline.yml` จาก `if:` ไปใช้ `env:` + `$GITHUB_OUTPUT` (แก้ parse error 0s) — DONE (2026-11-24 · YAML validated 3/3 workflows)
- [x] **UX v3 & Data Precision Overhaul (11 รายการจาก Founder):** ชื่อแอป `แจ้งเตือนน้ำท่วมยะลา`, กรอบเขื่อนบางลางด้านบน, แผนที่เฉพาะยะลา 3 ระดับความสูง (`8 อำเภอ → 58 ตำบล → 449 หมู่บ้าน` ด้วย Copernicus DEM MSL), ย้ายข้อมูลไปแถบ `ข้อมูล`, ศูนย์พักพิงอ้างอิงข้อมูลเดิม 8 อำเภอ + เอาป้าย "พิกัดโดยประมาณ" ออก, เพิ่มลิงก์ LINE/Facebook ที่ตรวจสอบ HTTP 200 แล้ว, ซ่อนคำเทคนิค `formula v2`, และแยกสวิตช์เสียงแจ้งเตือน/ข้อความ Notification — DONE (2026-11-24 · `DEC-015` · `pytest 27/27 passed`, `flutter analyze 0 issues`, `flutter test 45/45 passed`)
- [x] Founder ตั้งค่า Supabase Project (`ibrdiroqzgqykxpttafj.supabase.co`) + GitHub Secrets + GitHub Actions Pipeline (ยืนยัน `latest.json` HTTP 200 OK ขนาด 91.8 KB ใช้งานจริงแล้ว) — DONE (2026-11-24)
- [ ] ขอพิกัดศูนย์พักพิงรายตำบลและเบอร์ตรงที่ว่าการอำเภออีก 7 อำเภอจาก ปภ.ยะลา (`pending_ddpm_verify` → `verified`) — WAITING FOUNDER

## Phase 3 — iOS App Store Readiness, Push Engine & Accessibility `[DONE — AI Team · Ready for Founder TestFlight]`
- [x] สร้างไอคอน iOS จริงครบ 15 ขนาด (`1024×1024` No-Alpha) + `PrivacyInfo.xcprivacy` (ลงทะเบียนใน `project.pbxproj` + `plutil -lint OK`) + `ITSAppUsesNonExemptEncryption=false` + `UIBackgroundModes=[remote-notification]` + จัด Bundle ID (`net.yala.floodapp`) และเวอร์ชัน (`0.4.0+4`) ให้ตรงกัน — DONE (2026-11-24 · `DEC-016`)
- [x] พัฒนาระบบ FCM Topic รายอำเภอ (`yala_flood_all` + 8 อำเภอ ASCII) ตรงกัน 100% ระหว่าง `NotificationService` และ `backend/notify_fcm.py` (30m Cooldown + 2h Hysteresis decay + SHA-256 Fail-Closed + `actions/cache@v4` state) + รองรับปิดเสียงจริงบน iOS/Android — DONE (2026-11-24)
- [x] เพิ่มโหมดตัวอักษรใหญ่สำหรับผู้สูงอายุ (`largeTextMode`) + Dynamic 4-Language Locale (`th`/`en`/`zh`/`ms`) + Fail-Closed Mobile CDN Snapshot Verification & Local Cache (`SnapshotService`) + ป้องกัน `device_hash` ใน Supabase view (`public_community_reports`) — DONE (2026-11-24)
- [x] สร้าง CI Workflow (`.github/workflows/ci.yml`), สคริปต์ `mobile/app/scripts/release_preflight.sh`, และชุด Launch Kit ครบชุด (`docs/launch/founder-action-guide.md`, `app-store-metadata.md`, `ddpm-yala-verification-letter.md`) — DONE (2026-11-24)
- [x] **Founder:** สร้าง App ID `net.yala.floodapp` + APNs Key (`.p8` Dev/Prod) + วาง `GoogleService-Info.plist` (`yala-flood-watch`) + ใส่ GitHub Secret `FIREBASE_SERVICE_ACCOUNT_JSON` — DONE (2026-11-24)
- [x] **AI Team (4.2–4.3):** ผูก `GoogleService-Info.plist` เข้า Target `Runner` + สร้าง `Runner.entitlements` (`aps-environment`) + ตั้งค่า Automatic Signing (`DEVELOPMENT_TEAM=4884CSRPSY`) + เปิด Capability `Push Notifications` ใน `project.pbxproj` (`plutil -lint OK`) — DONE (2026-11-24)
- [x] **Pre-TestFlight Lean, Stability & Security Hardening + Independent QA v4 `PASS` (`DEC-017`):** แก้ cold-start APNs race, ลด FCM sync 9→0/2 calls, ตัด double CDN fetch, บังคับ HTTPS + Yala bbox + TypeError/NaN fail-closed + UTF-8 decode, GPS 15s timeout, PDPA full wipe ครบ 5 user keys, และ Build Release IPA ใหม่ (`yala_flood_app.ipa` 24.0 MB, `0.4.0+4`, `aps-environment=production`, `beta-reports-active=true`) ผ่าน Independent QA Re-Audit **`PASS`** (`docs/qa/audit-2026-11-24-v4-testflight-hardening.md`, `pytest 28/28`, `flutter analyze 0 issues`, `flutter test 50/50`) — DONE (2026-11-24)
- [x] **Step 4.5 (Upload to TestFlight):** อัปโหลดบิลด์ `0.4.0` (Build `4`, `net.yala.floodapp`, 24.0 MB) ขึ้น Apple App Store Connect / TestFlight สำเร็จสมบูรณ์ (`xcodebuild -exportArchive` → `Progress 100%: Upload succeeded. ** EXPORT SUCCEEDED **`, ผ่านการตรวจ App Store Connect + SPI Analysis โดยไม่พบข้อผิดพลาด) — DONE (2026-11-24)
- [x] **v0.5.0+5 — Formula v3 (Research-Calibrated) & UX v4 8-Point Overhaul (`DEC-018`):** อัปเกรดสูตรเตือนภัย `formula_version = 3` จากบทวิจัยน้ำท่วมยะลา 2567–2568 (`watch_m/critical_m` สทภ.8, `R1/R24/R72`, `API_7d`, GloFAS, Bang Lang inflow, Bank-Overflow & Urban Pluvial Overrides, Sensor-Gap Fallback, Hysteresis 3h), แก้ iOS Dark Mode Contrast ทุกหน้า/ป้ายแผนที่, เส้นขอบเว้าโค้ง GADM 4.1 (8 อำเภอ/58 ตำบล/422 โซนหมู่บ้าน), Layer สีไล่ระดับตามความสูง Copernicus DEM 100%, ป้ายชื่อสถานีจริง (`บ้านปายอยือนิ`), คำอธิบายระดับแจ้งเตือน 1–5 ในตั้งค่า, พิกัด GPS (PDPA) & ปักหมุดแผนที่เทียบความสูง/ระดับน้ำ, และแปลครบ 4 ภาษาเต็มรูปแบบ — DONE (2026-11-24 · `pytest 42/42`, `flutter analyze 0 issues`, `flutter test 66/66`, live pipeline `v3 degraded=0`)
- [x] **Independent QA Audit & Re-Audit v5 (Context แยก):** ตรวจพบ 0 BLOCKER, 0 HIGH, 5 MEDIUM → แก้ไขครบทั้ง 5 จุดและผ่าน Re-Audit Verdict **`PASS`** (`docs/qa/audit-2026-11-24-v5-formula3-ux4.md`, `pytest 42/42`, `flutter analyze 0 issues`, `flutter test 66/66`) — DONE (2026-11-24)
- [ ] **Founder:** เปิด TestFlight บน iPhone จริงทดสอบฟังก์ชันหลัก (แผนที่ยะลา 3 ระดับ, ข้อมูล 5 ฐานข้อมูลจาก Supabase CDN, Push Notification, โหมดออฟไลน์, SOS/ศูนย์พักพิง) ก่อนอนุมัติ Gate 3 ส่งตรวจ Apple App Store — WAITING FOUNDER
- [ ] **Founder:** รัน `./scripts/release_preflight.sh "<SUPABASE_CDN_URL>"` / Xcode Archive และทดสอบบน iPhone จริงผ่าน TestFlight — WAITING FOUNDER

## Phase 4 — Independent QA Sign-Off & App Store Launch `[READY FOR FOUNDER GATE 3]`
- [x] **Independent Pre-Release v3 / Gate 3 QA Audit & Re-Audit (Context แยก):** ตรวจพบ 3 HIGH + 3 MEDIUM + 2 LOW → แก้ไขครบทั้งหมดและผ่าน Re-Audit Verdict **`PASS`** (`docs/qa/audit-2026-11-24-v3-pre-release.md`, `pytest 28/28`, `flutter analyze 0 issues`, `flutter test 45/45`) — DONE (2026-11-24)
- [ ] **Founder Gate 3 Sign-Off & Submission:** กรอก App Store Connect ตาม `docs/launch/app-store-metadata.md` และส่งตรวจ Apple App Store (ฟรี 100%) — WAITING FOUNDER
