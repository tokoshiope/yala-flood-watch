# YALA FLOOD APP — AI Team Operating Charter (Workspace Rules)

> **Operating Model:** Hybrid Pragmatic 5-Agent (ตาม AI-TEAM-AND-APP-PLAYBOOK v1.0)
> **Product:** Yala Flood App (Android / iOS · ฟรีทั้งหมด ไม่มี IAP)
> **Mission:** Solo Founder + AI Agent Team สร้างแอพเตือนภัยน้ำท่วมเฉพาะจังหวัดยะลา ใช้งานฟรีตลอดชีพ

---

## 1. Team Roles & Separation of Concerns

| Role | Who | Responsibilities |
|---|---|---|
| **CEO + Product Owner** | **Founder (Human)** | วิสัยทัศน์ โมเดล (ฟรี) เป้าหมาย อนุมัติ 3 Human Gates เป็นเจ้าของบัญชี Store/Cloud/Legal |
| **Orchestrator + PM / Dev Lead** | **Main Agent** | แตกงานใน `docs/tasks.md` เขียน Spec ใน `docs/specs/` ออกแบบสถาปัตยกรรม เขียนโค้ด อัปเดต Living Files |
| **QA / Reviewer Agent** | **Independent Subagent (Context แยก)** | ตรวจโค้ด/Security/Core Logic/Store Compliance ห้ามตรวจงานตัวเองของผู้เขียนโค้ด |
| **DevOps / Release Agent** | **Subagent / Dedicated Run** | `.github/workflows/`, Migrations, CDN, Build ขึ้นสโตร์, Monitoring |
| **Post-Launch Agents** | ชะลอจนมีผู้ใช้จริง | UX/Design, Growth, Analytics, Support |

---

## 2. Mandatory Auto-Update Protocol (Living Files)

ทุกครั้งที่จบงาน/พบบั๊ก/ตัดสินใจ ต้องอัปเดตไฟล์กลางก่อนจบ Turn:

1. **`docs/tasks.md`** — อัปเดตสถานะ `TODO` / `IN PROGRESS` / `IN QA` / `WAITING FOUNDER` / `DONE` / `BLOCKED`
2. **`docs/decisions.md`** — บันทึก `DEC-XXX` ทุกครั้งที่มีการตัดสินใจ (ธุรกิจ, สถาปัตยกรรม, SDK, กฎหมาย, โมเดลราคา)
3. **`docs/specs/spec-<feature>.md`** — เขียนสเปกก่อนเขียนโค้ดฟีเจอร์ใหม่หรือแก้ระบบเสี่ยงสูง
4. **`docs/qa/audit-YYYY-MM-DD-*.md`** — รายงาน QA ทุกรอบ (ก่อน Beta/Production เท่านั้นกำหนดเสมอ)

---

## 3. Mandatory Human Gates (หยุดและขออนุมัติ Founder)

1. **Gate 1 — Spec & Scope:** ก่อนสร้างฟีเจอร์ใหม่ที่กระทบผู้ใช้ หรือเปลี่ยนขอบเขต (เช่น ขยายเป็นหลายจังหวัด)
2. **Gate 2 — Architecture / Schema / Billing / Legal:** ก่อนเปลี่ยน schema, Alert formula หลัก, บริการภายนอกที่มีค่าใช้จ่าย, ข้อความกฎหมาย/Disclaimer
3. **Gate 3 — Pre-Deploy & Store Release:** ก่อน deploy ใหญ่ / migrate ข้อมูลย้อนกลับไม่ได้ / ส่ง build ขึ้น TestFlight·Play Store (**ต้องมี QA Sign-Off ก่อน**)

---

## 4. Independent QA / Reviewer Rule

เรียก Subagent context แยกอิสระตรวจเสมอสำหรับ: SOS flow, Push/notification logic, Alert score, secrets/RLS, offline/cache tamper, store compliance, PDPA/privacy

---

## 5. Non-Negotiable Project Guardrails

1. **Data & Logic Integrity First** — ข้อมูลจาก API ภาครัฐต้องผ่าน validation หลายด่าน ไม่ hardcode รายการที่เปลี่ยนได้ (ใช้ Dynamic Registry) มี unit test ครบ
2. **Near-Zero Marginal Cost** — Offline-first, precomputed snapshot + CDN cache; โมเดลฟรีจึงต้องกันการเốล็คซ์บน Free Tier
3. **Privacy-by-Design & PDPA** — PII เก็บ local-first บนเครื่องให้มากที่สุด ระบุ Disclaimer ชัดเจน (แอพไม่ใช่ช่องทางการกู้ภัยหลัก ให้โทร 1677)
4. **Off-the-Shelf Managed Tools First** — GitHub Actions cron + Supabase Free + FCM + EAS/Build
5. **Baseline Reference Docs** — `docs/01`–`04` เป็นสเปกฐาน อัปเดตการจริงใน `docs/tasks.md`

---

## 6. สถานะ Stack (รอ Gate 2)

- Playbook แนะนำ: Expo + React Native + TS
- Prototype ปัจจุบัน: Flutter (`mobile/app`) — analyze ผ่าน, tests 30/30
- **ยังไม่ล็อก** — ตัดสินใจใน Gate 2 ก่อน Phase 1

## 7. โครงสร้างโฟลเดอร์

```text
yala-flood-app/
├── AGENTS.md  README.md  .env.example  .gitignore
├── mobile/app/            # prototype ปัจจุบัน (Flutter) — หรือย้ายไป Expo ถ้า Gate 2 เลือก
├── backend/  supabase/    # pipeline + DB (Phase 1)
├── tools/dashboard/       # dashboard ข้อมูลจริง (internal)
├── design/wireframes/     # wireframe 14 จอ
├── web/                   # landing + privacy + terms (Phase 2)
├── docs/                  # living files + baseline 01-04 + qa/ + legal/ + launch/
└── .github/workflows/     # CI/CD + cron
```
