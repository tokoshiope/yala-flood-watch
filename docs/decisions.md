# Decisions Log (Living File)

## DEC-001 — ขอบเขตภูมิศาสตร์: เฉพาะจังหวัดยะลาก่อน
- **วันที่:** 2026-11-23
- **ตัดสินใจ:** MVP แรกเฉพาะ จ.ยะลา (8 อำเภอเป้าหมาย: เมืองยะลา รามัน ยะหา กรงปินัง เบตง บันนังสตา ธารโต กาบัง) ขยายภาคใต้ต่อใน Phase 6
- **เหตุผล:** ข้อมูลยะลาครบ (14 สถานี), มีภัยจริง (พ.ย. 2568), ทดสอบและวัดผลได้เร็ว
- **กระทบ:** ทุกเอกสาร baseline, dashboard, wireframe, tasks

## DEC-002 — โมเดลราคา: ฟรีทั้งหมด ไม่มี IAP
- **วันที่:** 2026-11-23
- **ตัดสินใจ:** ไม่มี paywall/IAP/subscription ตามคำร้องขอของ Founder (แอพสาธารณประโยชน์)
- **เหตุผล:** ผู้ใช้คือประชาชนในพื้นที่เสี่ยง; เสนอต่อทุนจากภาครัฐ/มูลนิธิ/ESG
- **กระทบ:** playbook เดิมที่ออกแบบไว้สำหรับ Freemium ต้องตัดส่วน Billing/IAP ออกจาก roadmap; docs/launch ไม่ต้องมี paywall assets
- **สถานะ:** ยืนยันแล้วโดย Founder

## DEC-003 — สูตรคะแนนเตือนภัย (Alert Score)
- **วันที่:** 2026-11-23
- **ตัดสินใจ:** `Score = 0.5×W(ระดับน้ำ) + 0.25×R(ฝนจริง) + 0.15×F(พยากรณ์ฝน) + 0.10×C(รายงานชุมชน)` ระดับ 1–5
- **เหตุผล:** ระดับน้ำเป็นตัวทำนายที่น่าเชื่อถือที่สุด; ฝนอย่างเดียวไม่ push
- **กระทบ:** `mobile/app/lib/services/alert_engine.dart`, `docs/04-core-methodology.md` (formula_version)
- **สถานะ:** Draft — รอ Gate 2 ยืนยันน้ำหนัก/เกณฑ์

## DEC-004 — Tech Stack: รอตัดสินใจ Gate 2
- **วันที่:** 2026-11-23
- **ตัวเลือก A:** คง Flutter (`mobile/app`) — prototype พร้อม 31 ไฟล์, tests 30/30, ใช้ API จริงได้
- **ตัวเลือก B:** ย้าย Expo + React Native + TS ตาม Playbook (EAS Build ผ่านตรง, ecosystem การเงิน/IAP ครบถ้วน)
- **คำแนะนำของ Main Agent:** คง Flutter (ประหยัด ~2 สัปดาห์ ไม่เขียนใหม่) แล้วใช้ Codemagic/GitHub Actions สำหรับ build; แต่หากต้องการเป็นไปตาม Playbook 100% ให้ย้าย Expo
- **สถานะ:** ✅ ยืนยันแล้ว (Gate 2 ผ่าน 23 พ.ย. 2568)

## DEC-006 — Gate 1 & Gate 2 ผ่านทั้ง 5 ข้อ (2026-11-23)
- **ตัดสินใจ:** Founder อนุมัติ: (1) MVP เฉพาะยะลา (2) ฟรีทั้งหมด (3) **คง Flutter** (4) pipeline snapshot/CDN + FCM (5) Alert Score ตาม DEC-003
- **ผล:** Phase 1 เริ่มได้ทันที

## DEC-007 — Registry แยกจาก API (Phase 1)
- **ตัดสินใจ:** `backend/registry/stations.yaml` generate จาก API จริงแต่เก็บใน repo (metadata: risk_zone/left_bank/agency) เพื่อลด coupling; สถานีใหม่ไม่ใช่ registry ได้ risk_zone เริ่มต้น
- **กระทบ:** backend/pipeline.py load_registry()

## DEC-008 — Fail-closed + MAX_STALE_MINUTES=30
- **ตัดสินใจ:** pipeline exit(1) และ **ไม่เขียนทับ** snapshot เมื่อ API ว่าง/ล่ม, ทุกสถานีเก่า >30 นาที, พิกัดนอกขอบเขต, ระดับน้ำว่าง+เก่า
- **เหตุผล:** ข้อมูลเสียทับข้อมูลดีอันตรายกว่าขาดข้อมูล (docs/03, docs/04 §2.1)

## DEC-005 — โครงสร้าง Repository มาตรฐาน + โฟลเดอร์เดียวใน Documents
- **วันที่:** 2026-11-23
- **ตัดสินใจ:** ใช้โครงสร้าง Playbook §6.1 ทั้งหมด รวมไฟล์เดิมทั้งหมดไว้ที่ `~/Documents/yala-flood-app/` (mobile/app, tools/dashboard, design/wireframes)
- **กระทบ:** path ทั้งหมดใน docs/tasks, README
