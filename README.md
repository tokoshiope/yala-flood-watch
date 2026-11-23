# 🌊 Yala Flood App

แอพเตือนภัยน้ำท่วม **เฉพาะจังหวัดยะลา** — ฟรีทั้งหมด สร้างโดย Solo Founder + AI Agent Team ตาม [AI-TEAM-AND-APP-PLAYBOOK v1.0]

## โครงสร้าง

```text
yala-flood-app/
├── AGENTS.md              # กฎทีม AI (Living)
├── mobile/app/            # prototype Flutter (analyze + tests 30/30)
├── tools/dashboard/       # dashboard ข้อมูลจริง (เปิดไฟล์ index.html ได้เลย)
├── design/wireframes/     # wireframe lo-fi 14 จอ (index.html + preview.png)
├── backend/ supabase/     # pipeline/DB (Phase 1)
├── web/                   # landing/privacy/terms (Phase 2)
├── docs/                  # PRD, baseline 01–04, tasks, decisions, specs/, qa/, legal/, launch/
└── .github/workflows/     # CI/CD (Phase 2)
```

## เริ่มต้น

### Dashboard (ไม่ต้องติดตั้งอะไร)
เปิด `tools/dashboard/index.html` ในเบราว์เซอร์ — ดึงข้อมูลสดจาก ThaiWater API (`province_code=95`)

### Flutter Prototype
```bash
export PATH="/Users/tokyo/flutter-sdk/bin:$PATH"
cd mobile/app
flutter pub get && flutter analyze && flutter test
```
> SDK ติดตั้งไว้ที่ `/Users/tokyo/flutter-sdk` (Flutter 3.50.1 stable)

## เอกสารสำคัญ
- `docs/PRD-yala-flood-app.md` — PRD เต็ม 1,011 บรรทัด
- `docs/tasks.md` — กระดานงาน (Living File)
- `docs/decisions.md` — บันทึกการตัดสินใจ DEC-XXX
- `AGENTS.md` — กฎทีม + Human Gates

## สถานะ
**Phase 0** — รอ Founder อนุมัติ Gate 1 (Scope) และ Gate 2 (Stack/Architecture) ก่อน Phase 1
