# Feature Specs — กฎและแม่แบบ

ก่อนเขียนโค้ดฟีเจอร์ใหม่หรือแก้ระบบเสี่ยงสูง **ต้อง**มี `spec-<feature>.md` ที่นี่ก่อน (ตาม AGENTS.md §2.3)

## แม่แบบ (คัดลอกจาก Playbook §6.3)

```markdown
# Spec: [ชื่อฟีเจอร์]
- **Task ID:** [เช่น C-02]
- **วันที่:** YYYY-MM-DD
- **สถานะ:** Draft | Approved (Gate 1) | Implemented | QA Signed-Off

## 1. ปัญหาและเป้าหมาย
## 2. ขอบเขต (In-Scope / Out-of-Scope / Free vs Paid)
## 3. User Stories & Acceptance Criteria
## 4. ผลกระทบสถาปัตยกรรม / ข้อมูล / ความปลอดภัย (Gate 2 Check)
## 5. แผนทดสอบสำหรับ QA/Reviewer Agent
```

## Spec ที่มีแล้ว

_(ยังไม่มี — เริ่มสร้างก่อน Phase 1)_

## หมายเหตุ
- PRD เต็มที่ `../PRD-yala-flood-app.md` เป็นเอกสารผู้บริหารผลิตภััณฑ์; spec เจาะลึกรายฟีเจอร์ ไม่เขียนทับ PRD
- ทุก spec ที่แตะ SOS/Push/Alert Score ต้องผ่าน Independent QA Subagent
