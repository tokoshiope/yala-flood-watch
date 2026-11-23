# Yala Flood App — Task Board (Living File)

> อัปเดตทุกครั้งที่จบงาน · Status: TODO / IN PROGRESS / IN QA / WAITING FOUNDER / DONE / BLOCKED

## Phase 0 — Inception & Baseline Docs  `[DONE]`
- [x] A. Dashboard ข้อมูลจริง 14 สถานี — DONE (tools/dashboard) ตรวจสอบแล้ว
- [x] B. Prototype Flutter 6 หน้า + tests 30/30 — DONE (mobile/app) ตรวจสอบ flutter analyze/test แล้ว
- [x] C. PRD 1,011 บรรทัด — DONE (docs/PRD-yala-flood-app.md)
- [x] D. Wireframe 14 จอ — DONE (design/wireframes)
- [x] ย้ายโปรเจกต์ทั้งหมดไป `~/Documents/yala-flood-app/` — DONE (2026-11-23)
- [x] เอกสารฐาน 01–04 + AGENTS.md + tasks/decisions/specs — DONE (257/217/323/327 = 1,124 บรรทัด ตรวจ wc -l แล้ว)
- [x] แก้ PRD §9.6 test vectors ให้ตรงสูตร (87.5 / 2.5 / 20.5) — DONE 23 พ.ย. 2568
- [x] git init + baseline commit c583f93 — DONE
- [x] **Gate 1 + Gate 2** — ✅ Founder อนุมัติทั้ง 5 ข้อ (DEC-006)

## Phase 1 — Core Data / Backend Foundation  `[IN QA]`
- [x] สถาปัตยกรรม pipeline: ThaiWater + TMD cron → normalize → snapshot JSON (+ manifest hash) — DONE (`backend/pipeline.py` + workflow) รันจริงได้ 14 สถานี hash=1d8bd901
- [x] Validation gates (fail-closed) + unit tests — DONE **pytest 8/8 passed** (exit 0)
- [x] Station/Shelter/Contact registry (dynamic) — DONE (14 สถานี 7 flash/5 riverine/2 dam)
- [x] spec-data-pipeline.md — DONE
- [x] commit `d45ff10` — DONE
- [ ] **Independent QA audit** (context แยก) ของ pipeline + alert_engine.dart ก่อน Gate 3 — IN PROGRESS

## Phase 2 — Cloud Bridge, CI/CD, Legal Web
- [ ] GitHub repo private + workflows + Supabase/Storage free tier
- [ ] web/ index + privacy + terms → GitHub Pages (HTTP 200)

## Phase 3 — Mobile MVP
- [ ] ตัดสินใจ Stack (Flutter เดิม vs Expo RN) — รอ Gate 2
- [ ] Android/iOS platform folders + รันบน emulator จริง + screenshot
- [ ] Push notifications (FCM) + alert engine ตามสูตร

## Phase 4 — QA Audit & Beta
- [ ] Independent QA audit (context แยก) → re-audit PASS
- [ ] Real-device test: SOS, offline, push

## Phase 5 — Store & Launch
- [ ] Accounts 15% tier, assets, listing pack, submit

## Backlog / ค้างจาก prototype
- [ ] ฐานเบอร์โทรหน่วยงาน 8 อำเภอ + webhook ศูนย์ปภ.ยะลา (SOS ตอนนี้จำลอง)
- [ ] จุดอพยพเป็นข้อมูลตัวอย่าง — ต้องใช้ข้อมูลจริงจาก ปภ.ยะลา
- [ ] TMD rainfall/rain forecast endpoint จริง (ตอนนี้เป็น model เฉพาะ)
- [ ] i18n ภาษายาลอ (ตัวอย่างข้อความ)

## Backlog / พบจาก Data Audit (23 พ.ย. 2568)
- [ ] 5 สถานีไม่มี `situation_level` → ใช้ fallback `W = situation/4` หรือฟัง `left_bank` (ดู docs/04 §2.1)
- [ ] 2 สถานีไม่มีตลิ่ง (`left_bank = 0`: เขื่อนบางลาง, ฝายละแอ) → ต้องนิยาม W แยก (situation/4)
- [x] cadence ข้อมูลจริง ~10–30 นาที (ไม่ใช่ 15 นาทีทุกสถานี) — fail-closed >30 นาที ถูกใส่ใน pipeline แล้ว
- [x] git init — DONE (baseline c583f93)
