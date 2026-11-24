# Phase 2 Cloud Bridge & iOS TestFlight Setup Runbook

คู่มือทีละขั้นตอนสำหรับ Founder เพื่อเชื่อมต่อ **Supabase Free Tier CDN + GitHub Pages (PDPA/Terms) + Xcode/TestFlight** โดยยังคงต้นทุน **฿0/เดือน (Near-Zero Marginal Cost)**

---

## 1. ตั้งค่า Supabase Free Tier (Database + Public Snapshot CDN)

1. สร้างโปรเจกต์ใหม่ที่ [supabase.com](https://supabase.com) เลือก Region: **Southeast Asia (Singapore)**
2. เปิด **SQL Editor** แล้วรันสคริปต์ migration:
   - `supabase/migrations/0001_initial_yala_flood_schema.sql`
   - สคริปต์จะสร้าง bucket `snapshots` (public read-only), ตาราง `community_reports` (RLS + Yala BBox + 90-day retention), RPC `submit_community_report` (จำกัด 1 รายงาน/เครื่อง/ชม.) และ `purge_expired_reports()`
3. คัดลอกค่าจาก **Project Settings → API**:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY` (เก็บเป็น GitHub Secret เท่านั้น ห้ามใส่ในแอปมือถือ!)

---

## 2. เปิดใช้งาน GitHub Actions Auto-Sync + Legal Web (GitHub Pages)

1. อัปโหลด repo ขึ้น GitHub (Private หรือ Public Open-Source)
2. ไปที่ **Settings → Secrets and variables → Actions** เพิ่ม:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
3. ไปที่ **Settings → Pages → Source: GitHub Actions** → กดรัน workflow `deploy-legal-web-pages`
   - จะได้ URL สาธารณะสำหรับใส่ใน Apple App Store Connect:
     - Privacy Policy: `https://<org>.github.io/<repo>/privacy.html`
     - Terms / Support: `https://<org>.github.io/<repo>/terms.html`
4. กดรัน workflow `yala-flood-data-pipeline` แบบ Manual (`workflow_dispatch`) เพื่อทดสอบอัปโหลด snapshot ขึ้น Supabase CDN ครั้งแรก

---

## 3. Build แอป Flutter iOS เชื่อม Supabase CDN จริง

```bash
export PATH="/Users/tokyo/flutter-sdk/bin:$PATH"
cd "/Users/tokyo/Documents/Yala Flood/mobile/app"

# รันพร้อมชี้ไปที่ Supabase Storage Public CDN ของคุณ:
flutter build ios --release \
  --dart-define=YALA_SNAPSHOT_CDN_BASE=https://<your-project>.supabase.co/storage/v1/object/public/snapshots
```

- เปิด `mobile/app/ios/Runner.xcworkspace` ใน Xcode 27.2
- ตั้งค่า **Signing & Capabilities**: เลือก Apple Developer Team และปรับ Bundle Identifier เป็น `net.yala.floodapp` ให้ตรงกับ `Info.plist`
- Product → Archive → Distribute App → **TestFlight** (หลังผ่าน Independent QA Gate 3 Sign-Off)

---

## 4. รายการรอยืนยันจากทางราชการ (Zero-Hallucination Checklist)
- [ ] ยืนยันพิกัดละเอียดของศูนย์พักพิงทั้ง 4 แห่งในเขตเทศบาลนครยะลา + รายชื่อศูนย์พักพิงอีก 7 อำเภอกับ ปภ.ยะลา (`073-203559`)
- [ ] ยืนยันเบอร์โทรศัพท์ตรงของที่ว่าการอำเภอ/ปภ.ท้องถิ่นอีก 7 อำเภอใน `backend/registry/contacts.yaml`
- [ ] ตั้งค่า `GoogleService-Info.plist` + APNs Key บน Firebase สำหรับ Remote Push Topic รายอำเภอ (`yala_flood:{amphoe}`)
