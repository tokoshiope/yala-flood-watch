# Spec: Data Pipeline & Station Registry (Phase 1)

- **Task ID:** P1-01
- **วันที่:** 2026-11-23
- **สถานะ:** Approved (Gate 1+2 ผ่านเมื่อ 23 พ.ย. 2568) · Implemented
- **ผู้อนุมัติ:** Founder (คำรับ "เห็นด้วยทั้งหมด ผ่านทั้ง 5 ข้อ")

## 1. ปัญหาและเป้าหมาย
แอพต้องได้ข้อมูลระดับน้ำ/สถานการณ์ที่ **ถูกต้อง ทันสมัย และไม่พัง** เมื่อแหล่งต้นทางล่ม โดยมีกลไกตรวจสอบหลายด่านแบบ fail-closed (ห้ามเขียนข้อมูลว่าง/เสียหายทับข้อมูลดี)

## 2. ขอบเขต
- **In-Scope:** fetch ThaiWater API (`province_code=95`) → normalize → validate → snapshot JSON + `manifest.json` (content_hash) · registry แยกไฟล์ (stations/contacts/shelters) · unit tests · GitHub Actions cron
- **Out-of-Scope:** การ publish ขึ้น Supabase/CDN (Phase 2) · TMD rainfall endpoint (backlog รอ key/endpoint ที่ชัดเจน) · push notification
- **Free/Paid:** ฟรีทั้งหมด (DEC-002) — pipeline ต้องรันฟรีบน GitHub Actions

## 3. User Stories & Acceptance Criteria
- [x] AC-1: pipeline ดึง API จริงได้ ≥14 สถานี พร้อม name/level/bank/situation/datetime
- [x] AC-2: ถ้า API ล่ม/คืนข้อมูลว่าง/ทุกสถานีเกิน 30 นาที → exit(1) และ **ไม่** เขียนทับไฟล์เดิม (fail-closed)
- [x] AC-3: snapshot มี content_hash (sha256) ใน manifest เสมอ
- [x] AC-4: สถานีที่ไม่มี `situation_level`/ตลิ่ง=0 ยังอยู่ใน snapshot พร้อม flag (`situation=null`, `bank=null`) ตาม docs/04 §2.1
- [x] AC-5: unit tests ครอบคลุม: parse, validate pass/fail, stale, hash deterministic, registry merge

## 4. ผลกระทบ Gate 2
- ไฟล์: `backend/pipeline.py`, `backend/registry/*.yaml`, `backend/tests/`, `.github/workflows/data-pipeline.yml`, `backend/output/` (gitignore)
- ต้นทุน: ฿0 (GitHub Actions free) · Privacy: ไม่มี PII · Legal: ข้อมูลจาก API ภาครัฐ ตามสิทธิ์สาธารณะ

## 5. แผนทดสอบ QA (context แยก)
- Happy: ข้อมูลจริง 14 สถานี, hash ตรงกับ re-run
- Edge: เน็ตขาด, JSON เสีย, 0 records, สถานีเดียวเก่าเกิน 30 นาที, พิกัดศูนย์
