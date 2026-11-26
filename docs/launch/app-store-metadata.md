# App Store Connect Metadata & Review Submission Kit (`v1.0.1 Build 8`)

เอกสารคัดลอกวาง (Copy-Paste Ready) สำหรับส่งแอป **แจ้งเตือนน้ำท่วมยะลา (Yala Flood Warning)** ขึ้น Apple App Store พร้อมคำตอบครบทั้ง 6 ข้อตาม **Guideline 2.1 - Information Needed**

---

## 1. ข้อมูลพื้นฐาน (App Information)

| ช่องใน App Store Connect | ค่าที่แนะนำ |
|---|---|
| **App Name (Thai)** | `แจ้งเตือนน้ำท่วมยะลา` |
| **Subtitle (Thai, ≤30 chars)** | `แผนที่ระดับน้ำ-ฝน-เขื่อนบางลาง` |
| **App Name (English)** | `Yala Flood Warning` |
| **Subtitle (English, ≤30 chars)** | `Early Flood Alerts for Yala` |
| **Bundle ID** | `net.yala.floodapp` |
| **Version / Build** | `1.0.1` (Build `8`) |
| **Primary Category** | `Weather` (สภาพอากาศ) |
| **Secondary Category** | `Utilities` (เครื่องมือ) |
| **Pricing** | **Free (฿0 / $0)** — Zero In-App Purchases, Zero Ads |
| **Age Rating** | `4+` (ไม่มีเนื้อหาความรุนแรง/พนัน/บัญชีผู้ใช้/UGC) |
| **Privacy Policy URL** | `https://tokoshiope.github.io/yala-flood-watch/privacy.html` |
| **Support URL** | `https://tokoshiope.github.io/yala-flood-watch/terms.html` |
| **Export Compliance** | `No` (`ITSAppUsesNonExemptEncryption = false`) |

---

## 2. Keywords (≤100 characters)

- **Thai:** `น้ำท่วมยะลา,แจ้งเตือนน้ำท่วม,ยะลา,เขื่อนบางลาง,ระดับน้ำ,ศูนย์พักพิง,ปภ,ฝนยะลา,เบตง,รามัน`
- **English:** `yala,flood,warning,thailand,bang lang dam,water level,rain forecast,shelter,emergency,alert`

---

## 3. Description (คำอธิบายแอป)

### ภาษาไทย (Primary)
```text
แจ้งเตือนน้ำท่วมยะลา — แอปพลิเคชันเฝ้าระวังและแจ้งเตือนภัยน้ำท่วมล่วงหน้าเฉพาะจังหวัดยะลา (ครบทั้ง 8 อำเภอ 58 ตำบล 449 หมู่บ้าน) ฟรี 100% ไม่มีโฆษณา และไม่ต้องสมัครสมาชิก

ความสามารถหลัก:
• สถานะเขื่อนบางลางแบบเรียลไทม์ — ติดตามความจุน้ำ ปริมาณน้ำ และการระบายน้ำจากเขื่อนบางลางได้ทันทีจากหน้าแรก
• แผนที่เฉพาะจังหวัดยะลาแบบ 3 ระดับความสูง — ดูระดับแจ้งเตือนรายอำเภอ กดขยายลงระดับตำบลและหมู่บ้าน พร้อมสีประเมินความเสี่ยงน้ำท่วมถึงจากความสูงภูมิประเทศจริงเทียบระดับน้ำแม่น้ำ
• ข้อมูลน้ำและกราฟพยากรณ์ฝนรายชั่วโมง — กราฟแท่งพยากรณ์ฝนรายชั่วโมงล่วงหน้า 24 ชม. (เวลาประเทศไทย UTC+7), สรุปสถานการณ์รายอำเภอระบุชื่อหมู่บ้านและตำบลที่ต้องเฝ้าระวังชัดเจน, และสถานีวัดระดับน้ำ 14 แห่งที่เน้นแสดง "ระยะเหลือถึงตลิ่ง" พร้อมกราฟแนวโน้มระดับน้ำย้อนหลัง 7 วันแบบโต้ตอบได้
• ช่องทางฉุกเฉิน 1 แตะ — รวมเบอร์โทรด่วนและช่องทาง LINE / Facebook ทางการที่ตรวจสอบแล้ว เช่น 1784 (ปภ.), 073-203559 (ปภ.ยะลา), 073-212345 (เทศบาลนครยะลา), 1669, 199, 191
• ศูนย์พักพิงและนำทางด้วย Google Maps — ค้นหาศูนย์พักพิงตามอำเภอ พร้อมปุ่มนำทาง Google Maps และปุ่มกดโทรพร้อมแสดงหมายเลขโทรศัพท์ชัดเจน
• รองรับ 4 ภาษา — ไทย, English, 中文 และ Bahasa Melayu พร้อมโหมดตัวอักษรใหญ่สำหรับผู้สูงอายุ แยกเปิด/ปิดเสียงแจ้งเตือนและข้อความ Notification ได้อิสระ
• ใช้งานได้แม้ไม่มีอินเทอร์เน็ต — เก็บข้อมูลล่าสุดและแนวโน้มย้อนหลังไว้ในเครื่องให้ดูได้แม้สัญญาณขัดข้อง เคารพความเป็นส่วนตัวตาม PDPA ไม่เก็บข้อมูลผู้ใช้บนเซิร์ฟเวอร์ และไม่ติดตามพิกัดพื้นหลัง

หมายเหตุสำคัญ: แอปนี้เป็นโครงการสาธารณประโยชน์อิสระ ไม่ใช่แอปอย่างเป็นทางการของหน่วยงานรัฐ และไม่ใช่ช่องทางกู้ภัยหลัก หากเกิดเหตุฉุกเฉินเร่งด่วนกรุณาโทร 1784, 073-203559 หรือ 1669 ทันที
```

### English
```text
Yala Flood Warning is a 100% free, ad-free civic early flood warning app dedicated exclusively to Yala Province, Thailand (all 8 districts, 58 subdistricts, and 449 villages). No account or sign-in required.

Key Features:
• Bang Lang Dam Status — Monitor reservoir storage, water volume, and daily release directly from the top of the Map screen.
• Yala-Only 3-Level Elevation Map — Explore flood risk by district, drill down to all 58 subdistricts and 449 villages colored by real terrain elevation (MSL) versus river water level.
• Hourly Rain Bar Chart & 7-Day Water Level Trends — View 24h hourly rain bar charts in Thailand time (UTC+7), village- and subdistrict-level watch lists, and 14 water-level stations highlighting remaining distance to bank with interactive 7-day trend charts.
• Verified Emergency Contacts — One-tap call, LINE, and Facebook links to Thailand DDPM (1784), Yala DDPM (073-203559), Yala Municipality (073-212345), EMS (1669), Fire (199), and Police (191).
• Evacuation Shelters — Filter shelters across all 8 districts with Google Maps turn-by-turn routing and direct call buttons displaying the phone number.
• 4 Languages & Accessibility — Supports Thai, English, Chinese, and Bahasa Melayu, plus Large Text Mode for elderly users and independent Alert Sound / Notification switches.
• Offline-First & Privacy-by-Design — Caches the latest telemetry locally, never uploads personal data, never tracks background location (When In Use only after explicit consent), and provides one-tap local data deletion.

Disclaimer: This is an independent public-interest tool, not an official government app or primary rescue dispatch channel. In life-threatening emergencies, call 1784, 073-203559, or 1669 directly.
```

---

## 4. App Privacy (Nutrition Labels ใน App Store Connect)

| คำถามใน App Store Connect | คำตอบที่ถูกต้องตรงกับ `PrivacyInfo.xcprivacy` (v1.0.1) |
|---|---|
| Do you or your third-party partners collect data from this app? | **No — Data Not Collected** (พิกัด GPS ประมวลผลเฉพาะในเครื่องเมื่อผู้ใช้กดยินยอม ไม่ส่งขึ้นเซิร์ฟเวอร์ · ไม่มีบัญชีผู้ใช้ · ไม่มี UGC · ตรงกับ `NSPrivacyCollectedDataTypes = []` ใน `PrivacyInfo.xcprivacy`) |
| Used for Tracking? | **No** (`NSPrivacyTracking = false`) |
| User-Generated Content (UGC)? | **None (0% UGC)** |
| Contact Info / Identifiers / Usage Data / Diagnostics? | **None / ไม่เก็บ** |

---

## 5. App Review Notes (Copy-Paste ลงช่อง App Review Information → Notes — ตอบครบทั้ง 6 ข้อของ Apple Guideline 2.1)

```text
Thank you for reviewing Yala Flood Warning (แจ้งเตือนน้ำท่วมยะลา). Please find all requested information for Guideline 2.1 below:

1. Physical Device Screen Recording:
   - Video URL (captured on physical iPhone running latest iOS): [REPLACE WITH YOUR UNLISTED YOUTUBE / ICLOUD / GOOGLE DRIVE VIDEO LINK]
   - The screen recording starts from launching the app on the iOS Home Screen and demonstrates the complete typical user flow across all 5 tabs:
     (a) Map tab: Bang Lang Dam status banner, 3-level district/subdistrict/village elevation map, optional GPS location (showing in-app PDPA consent prompt before iOS When-In-Use permission) and map pin elevation comparison.
     (b) Flood Info tab: iOS-style vertical hourly rain forecast bar chart, 14 water-level stations highlighting remaining distance to bank, tapping a station to view the interactive 7-day historical water-level trend chart (24h/3d/7d), and district overview detailing specific villages and subdistricts to watch.
     (c) Emergency Contacts tab: life-safety disclaimer and one-tap verified phone, LINE, and Facebook contact links.
     (d) Shelters tab: district filters, Google Maps routing, and direct call buttons displaying the exact phone number.
     (e) Settings tab: switching language to English, 1-5 alert level guide, Large Text Mode, alert toggles, and one-tap local data deletion ("Delete All My Data (PDPA)").
   - Account registration / login / deletion: Not applicable — this app has NO accounts, login, or registration. All local preferences, pins, GPS consent, and cached snapshots can be erased with one tap under Settings -> "Delete All My Data (PDPA)".
   - User-generated content (UGC): None — all SOS messaging and community reporting features have been completely removed. The app is read-only public telemetry and verified emergency contact links.
   - Paid content / IAP: None — the app is 100% free forever with zero in-app purchases, zero subscriptions, and zero ads.

2. App Purpose, Target Audience, Problem Solved & Value Provided:
   - Purpose & Audience: A 100% free civic early flood warning utility built for residents, households, and elderly citizens in Yala Province, Southern Thailand (all 8 districts, 58 subdistricts, and 449 villages).
   - Problem Solved: Hydrological telemetry in Yala is scattered across multiple agencies (HII, RID, EGAT, DWR) and weather models, making it difficult for citizens to know how close rivers are to overflowing or whether Bang Lang Dam releases threaten their specific village and subdistrict.
   - Value Provided: Unifies live water-level telemetry (highlighting remaining distance to bank and 7-day trends), Bang Lang Dam reservoir/spillway status, 24-hour hourly rainfall forecasts, terrain elevation flood-risk mapping, evacuation shelter locations, and verified emergency hotlines into a fast, offline-resilient, 4-language (Thai/English/Chinese/Malay) app with elderly Large Text Mode.

3. Setup & Testing Instructions:
   - No login, demo credentials, or sample files are required. All 5 tabs work immediately upon launch using live + bundled offline data.
   - To switch interface language to English: tap the 5th tab ("ตั้งค่า" / Settings) -> tap the first dropdown ("ภาษา / Language") -> select "🇬🇧 English".
   - On the Map tab: tap any district chip to drill down to subdistricts and villages; long-press anywhere inside Yala to drop a test pin and inspect ground elevation vs. river water level (works even when reviewing outside Thailand).
   - On the Info tab: tap any hour bar in the rain chart to inspect rainfall; tap any water-level station to view its 7-day historical trend chart and switch between 24h / 3d / 7d.

4. External Services, Tools, and Platforms Used:
   - ThaiWater Public API v3 (Hydro-Informatics Institute / HII, Thailand — https://api-v3.thaiwater.net): Public open data for 14 telemetric water-level stations, 7-day historical station graphs (`waterlevel_graph`), 87+ real-time rain gauges, and Bang Lang Dam telemetry.
   - Open-Meteo Weather Forecast & GloFAS v4 Flood APIs (CC BY 4.0 — https://open-meteo.com): 24-72h hourly rainfall forecasts and 7-day river discharge forecasts.
   - GitHub Actions & Supabase Storage CDN: Automated open-data snapshot pipeline (running every 10 minutes) publishing signed read-only JSON snapshots for offline resilience and low bandwidth.
   - Firebase Cloud Messaging (FCM) / APNs: Anonymous district topic push notifications (no accounts, no personal identifiers).
   - Google Maps tiles & standard external links (`tel:`, Google Maps directions, official agency LINE/Facebook URLs).

5. Regional Differences:
   - The app functions identically across all App Store regions and countries with no geo-blocking or regional feature differences. All hydrological data and maps are specifically scoped to Yala Province, Thailand (province code 95).

6. Regulated Industry / Protected Third-Party Material Authorization:
   - This app is an independent public-interest civic project — NOT an official government app and NOT a primary rescue dispatch service. Clear disclaimers appear in-app (Emergency Contacts & Settings tabs) and in our Terms of Use directing users in immediate danger to call official Thai emergency hotlines (1784 DDPM, 073-203559 Yala DDPM, 1669 EMS).
   - All hydrological data is sourced exclusively from Thailand's publicly open ThaiWater Public API v3 (no key or access restriction) and Open-Meteo (CC BY 4.0) with transparent in-app attribution.
```
