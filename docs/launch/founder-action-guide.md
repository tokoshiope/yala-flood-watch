# คู่มือขั้นตอนสำหรับ Founder (ส่วนที่ต้องดำเนินการด้วยตนเอง)

> **แอปพลิเคชัน:** แจ้งเตือนน้ำท่วมยะลา (`Yala Flood Watch`) · **Bundle ID:** `net.yala.floodapp`  
> **ต้นทุนระบบปฏิบัติการ:** ฿0/เดือน (GitHub Free + Supabase Free + Firebase Spark Free + 5 ฐานข้อมูลสาธารณะฟรี) · ค่าใช้จ่ายคงที่เดียวคือ Apple Developer Program (\$99/ปี)

ทีม Agent AI ดำเนินการด้านโค้ด, ฐานข้อมูล 5 แหล่ง, แผนที่ 3 ระดับ (8 อำเภอ → 58 ตำบล → 449 หมู่บ้าน), ไอคอนแอป 15 ขนาด, Privacy Manifest (`PrivacyInfo.xcprivacy`), ระบบส่ง Push (`notify_fcm.py`), เว็บไซต์ PDPA/Terms และชุดทดสอบอัตโนมัติเสร็จสมบูรณ์แล้ว เหลือเฉพาะ **6 ขั้นตอนด้านล่างที่ต้องใช้บัญชีและสิทธิ์ของ Founder เท่านั้น**

---

## ขั้นตอนที่ 1 — นำโค้ดขึ้น GitHub และเปิดหน้าเว็บนโยบาย (PDPA / Terms) (~10 นาที)

1. สร้าง Repository ใหม่บน [github.com/new](https://github.com/new) (แนะนำตั้งชื่อ `yala-flood-watch` เลือก Public หรือ Private ก็ได้ — หากใช้ GitHub Free และต้องการเปิด GitHub Pages ฟรีให้เลือก **Public**)
2. เปิด Terminal บน Mac แล้วส่งโค้ดขึ้น GitHub:
   ```bash
   cd "/Users/tokyo/Documents/Yala Flood"
   git remote add origin https://github.com/<ชื่อผู้ใช้ของคุณ>/yala-flood-watch.git
   git push -u origin main
   ```
3. เปิด **GitHub Pages** เพื่อใช้ URL ของ Privacy Policy & Terms ใส่ใน App Store Connect:
   - เข้าหน้า Repo → **Settings → Pages**
   - ที่หัวข้อ **Build and deployment → Source** เลือก **`GitHub Actions`**
   - ไปที่แท็บ **Actions** → เลือก **`deploy-legal-web-pages`** → กด **`Run workflow`**
   - รอ ~1 นาที จะได้ URL ใช้งานจริง:
     - หน้าแรก: `https://<ชื่อผู้ใช้ของคุณ>.github.io/yala-flood-watch/`
     - นโยบายความเป็นส่วนตัว (PDPA): `https://<ชื่อผู้ใช้ของคุณ>.github.io/yala-flood-watch/privacy.html`
     - ข้อกำหนด/คำชี้แจงความปลอดภัย: `https://<ชื่อผู้ใช้ของคุณ>.github.io/yala-flood-watch/terms.html`

---

## ขั้นตอนที่ 2 — สร้างฐานข้อมูลและ CDN ฟรีบน Supabase (~10 นาที)

1. สมัคร/เข้าสู่ระบบที่ [supabase.com](https://supabase.com) → กด **New Project**
   - ตั้งชื่อ: `yala-flood-watch`
   - เลือก Region: **`Southeast Asia (Singapore)`** (ใกล้ยะลาที่สุด เร็วที่สุด)
   - แผนราคา: **Free** (฿0/เดือน)
2. เมื่อโปรเจกต์พร้อม ให้เข้าเมนูซ้าย **SQL Editor → New query**
3. คัดลอกโค้ดทั้งหมดจากไฟล์ `supabase/migrations/0001_initial_yala_flood_schema.sql` มาวางแล้วกด **Run**
   - ผลลัพธ์: สร้าง Storage Bucket ชื่อ `snapshots` (อ่านสาธารณะได้เท่านั้น), ตาราง `community_reports` (เปิด RLS + จำกัดพิกัดเฉพาะ จ.ยะลา + ลบอัตโนมัติใน 90 วัน) และ RPC จำกัด 1 รายงาน/เครื่อง/ชม.
4. ไปที่ **Project Settings → API** แล้วคัดลอก 2 ค่านี้:
   - **Project URL** (เช่น `https://abcdefgh.supabase.co`)
   - **service_role secret key** *(ห้ามใส่ในแอปมือถือ! ใช้ใน GitHub Secrets เท่านั้น)*
5. กลับไปที่ GitHub Repo → **Settings → Secrets and variables → Actions → New repository secret** เพิ่ม 2 ตัวแปร:
   - `SUPABASE_URL` = Project URL ที่คัดลอกมา
   - `SUPABASE_SERVICE_ROLE_KEY` = service_role secret key
6. ทดสอบให้ระบบดึง 5 ฐานข้อมูลอัตโนมัติขึ้น CDN:
   - แท็บ **Actions** → **`yala-flood-data-pipeline`** → กด **`Run workflow`**
   - เมื่อขึ้นสีเขียว ให้เปิดเบราว์เซอร์ทดสอบ URL นี้ต้องเห็น JSON ของ จ.ยะลา 14 สถานี:
     `https://<project-ref>.supabase.co/storage/v1/object/public/snapshots/latest.json`
   - ต่อจากนี้ระบบจะอัปเดตข้อมูลให้เองอัตโนมัติ **ทุก 15 นาที ตลอด 24 ชั่วโมง**

---

## ขั้นตอนที่ 3 — เชื่อม Firebase + APNs สำหรับส่งข้อความ Push Notification (~15 นาที)

> *หมายเหตุ: หากต้องการทดสอบแอปใน TestFlight ก่อนโดยใช้เฉพาะแจ้งเตือนในเครื่อง สามารถข้ามขั้นตอนนี้ไปทำขั้นตอนที่ 4 ก่อนแล้วค่อยกลับมาเปิด Push ทีหลังได้ (โค้ดรองรับทำงานได้โดยไม่ค้างแม้ยังไม่มี Firebase)*

1. สมัคร **Apple Developer Program** (\$99/ปี) ที่ [developer.apple.com](https://developer.apple.com) (หากยังไม่มี)
2. สร้าง **APNs Auth Key (.p8)** ใน Apple Developer Portal:
   - เข้า **Certificates, Identifiers & Profiles → Keys → +**
   - ตั้งชื่อ `Yala Flood APNs Key` → ติ๊ก **`Apple Push Notifications service (APNs)`** → Continue → Register → **Download ไฟล์ `.p8`** (เก็บไว้ให้ดี โหลดได้ครั้งเดียว) พร้อมจด **Key ID** และ **Team ID**
3. สร้างโปรเจกต์ฟรีบน [console.firebase.google.com](https://console.firebase.google.com) (แผน Spark ฟรี):
   - กด **Add app → iOS** → ใส่ Apple Bundle ID: **`net.yala.floodapp`**
   - ดาวน์โหลดไฟล์ **`GoogleService-Info.plist`** แล้วนำไปวางที่:
     `/Users/tokyo/Documents/Yala Flood/mobile/app/ios/Runner/GoogleService-Info.plist`
   - ไปที่ **Project Settings → Cloud Messaging → Apple app configuration** → อัปโหลดไฟล์ **`.p8`** พร้อมใส่ Key ID และ Team ID
4. เปิดให้ GitHub Actions ส่ง Push รายอำเภออัตโนมัติ:
   - ใน Firebase Console → **Project Settings → Service accounts → Generate new private key** (จะได้ไฟล์ `.json`)
   - เปิดไฟล์ `.json` คัดลอกข้อความทั้งหมดไปใส่เป็น GitHub Secret ชื่อ **`FIREBASE_SERVICE_ACCOUNT_JSON`**
   - ระบบ `backend/notify_fcm.py` จะส่ง Push แจ้งเตือนเข้าหัวข้อรายอำเภอ (`yala_flood_mueang_yala`, `yala_flood_raman`, ..., `yala_flood_all`) อัตโนมัติเมื่อเกิดระดับเตือนภัย

---

## ขั้นตอนที่ 4 — ตั้งค่า Xcode Signing และอัปโหลดขึ้น TestFlight (~15 นาที)

1. เปิดโปรเจกต์ iOS ใน Xcode บน Mac เครื่องนี้:
   ```bash
   open "/Users/tokyo/Documents/Yala Flood/mobile/app/ios/Runner.xcworkspace"
   ```
2. ใน Xcode คลิกที่ **Runner** (แถบซ้ายบนสุด) → แท็บ **Signing & Capabilities**:
   - ติ๊ก **Automatically manage signing**
   - เลือก **Team** = บัญชี Apple Developer ของคุณ
   - แก้ **Bundle Identifier** ให้เป็น **`net.yala.floodapp`** (ตรงกับ `Info.plist` และ Firebase)
   - กดปุ่ม **`+ Capability`** → เพิ่ม **`Push Notifications`** และตรวจสอบว่า **`Background Modes → Remote notifications`** ถูกติ๊กไว้แล้ว
   - ตรวจสอบในแถบซ้าย `Runner` ว่าไฟล์ **`PrivacyInfo.xcprivacy`** (และ `GoogleService-Info.plist` หากทำขั้นตอนที่ 3 แล้ว) อยู่ใน Target `Runner`
3. รันสคริปต์ตรวจสอบก่อนปล่อย + สร้างไฟล์ Release IPA ใน Terminal (แทนที่ `<project-ref>` ด้วยรหัส Supabase ของคุณ):
   ```bash
   cd "/Users/tokyo/Documents/Yala Flood/mobile/app"
   chmod +x scripts/release_preflight.sh
   ./scripts/release_preflight.sh "https://<project-ref>.supabase.co/storage/v1/object/public/snapshots"
   ```
   *(หรือใน Xcode เลือกปลายทาง **Any iOS Device (arm64)** → เมนู **Product → Archive** → **Distribute App → TestFlight & App Store**)*
4. ทดลองติดตั้งผ่านแอป **TestFlight** บน iPhone จริงของคุณเพื่อทดสอบ:
   - แผนที่เฉพาะ จ.ยะลา กดขยาย อำเภอ → ตำบล → หมู่บ้าน
   - เปิด/ปิดเสียงแจ้งเตือน, เปิด/ปิด Notification, เปลี่ยน 4 ภาษา และโหมดตัวอักษรใหญ่
   - ทดสอบโหมดเครื่องบิน (Offline) ว่ายังเปิดดูระดับน้ำล่าสุด ศูนย์พักพิง และโทร 1784 ได้
   - ทดสอบปุ่มนำทาง Google Maps และปุ่ม LINE / Facebook

---

## ขั้นตอนที่ 5 — กรอกข้อมูลและส่งตรวจบน Apple App Store Connect (~15 นาที)

1. เข้า [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps → + New App** (iOS, Bundle ID `net.yala.floodapp`, SKU `yala-flood-watch-ios`)
2. คัดลอกข้อความทุกช่อง (ชื่อแอป, คำอธิบายไทย/อังกฤษ, คีย์เวิร์ด, Privacy Nutrition Label, App Review Notes) จากไฟล์ที่ทีม AI เตรียมไว้ให้ครบแล้วที่:
   - `docs/launch/app-store-metadata.md`
3. จับภาพหน้าจอจาก iPhone จริง (6.7" หรือ 6.9") 5 หน้า: แผนที่ จ.ยะลา (รวมกรอบเขื่อนบางลาง), หน้าขยายระดับตำบล/หมู่บ้าน, แถบข้อมูล+กราฟฝน, แถบ SOS, และแถบศูนย์พักพิง
4. ตั้งราคา **Free ($0 / ฟรี)** → เลือก Build จาก TestFlight ที่ทดสอบผ่านแล้ว → กด **Add for Review** (หลังยืนยัน Gate 3)

---

## ขั้นตอนที่ 6 — ประสานงานยืนยันข้อมูลทางการกับ ปภ.ยะลา (ทำควบคู่ได้ตลอด)

- ส่งจดหมายหรือข้อความจากแบบฟอร์มพร้อมใช้ใน `docs/launch/ddpm-yala-verification-letter.md` ไปยัง:
  - **สำนักงาน ปภ. จังหวัดยะลา:** โทร `073-203559` หรือ LINE `@1784DDPM`
  - **งาน ปภ. เทศบาลนครยะลา:** โทร `073-212345` หรือ LINE `@yalacity`
- เมื่อได้รับพิกัดและรายชื่อศูนย์พักพิงยืนยันครบทั้ง 8 อำเภอ + เบอร์ตรงที่ว่าการอำเภอทั้ง 7 แห่ง เพียงส่งข้อมูลให้ทีม Agent AI อัปเดตใน `backend/registry/shelters.yaml` และ `contacts.yaml` เพื่อปลดป้าย `"อ้างอิงจากข้อมูลเดิม รอยืนยัน"` (ข้อมูลในแอปจะอัปเดตผ่าน CDN ได้ทันทีโดยไม่ต้องรอ Apple Review ใหม่!)
