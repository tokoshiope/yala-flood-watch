# App Store Connect Metadata & Review Submission Kit (`v1.0.1 Build 11`)

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
| **Version / Build** | `1.0.1` (Build `11`) |
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

## 5. App Review Notes (Copy-Paste ลงช่อง App Review Information → Notes — ตอบครบทั้ง 6 ข้อ ≤ 4,000 ตัวอักษร)

```text
Thank you for reviewing Yala Flood Warning (แจ้งเตือนน้ำท่วมยะลา). Below are all 6 items requested under Guideline 2.1:

1. Physical Device Screen Recording:
- Video URL (physical iPhone, latest iOS): [PASTE VIDEO LINK HERE]
- Shows app launch from Home Screen across all 5 tabs: Map (Bang Lang Dam status, quick 15s home-district setup, local-only Home & Family Watchlist up to 5 pins with offline voice briefing & 1-tap LINE/clipboard share card, 3-level district/subdistrict/village elevation map on CARTO/OSM tiles with offline caching, optional GPS with in-app PDPA consent before iOS When-In-Use prompt, and map pin comparison), Flood Info (iOS-style hourly rain bar chart with % probability, 14 water stations showing remaining-to-bank distance, interactive 7-day trend chart 24h/3d/7d, village/subdistrict watch lists), Emergency Contacts (disclaimer + phone/LINE/Facebook links), Shelters (dynamic OTA shelter list sorted nearest to user's pin, district filters, Google Maps routing, direct call buttons with phone numbers), and Settings (4-language switch, offline Evacuation Guide, 1-5 alert guide, Large Text Mode, one-tap data wipe).
- Accounts/Login/Deletion: None (no account or registration). One-tap local reset in Settings -> "Delete All My Data (PDPA)".
- UGC: None — all SOS messaging and community reporting were removed; read-only public telemetry & emergency directory only.
- Paid/IAP: None — 100% free forever, zero IAP, zero ads.

2. Purpose, Audience, Problem & Value:
- Free civic flood early-warning utility for residents and elderly citizens in Yala Province, Thailand (8 districts, 58 subdistricts, 449 villages).
- Problem: Hydrological data is split across agencies (HII, RID, EGAT, DWR) and weather models, making it hard to gauge river bank margins or Bang Lang Dam impacts per village.
- Value: Unifies live water levels (remaining-to-bank & 7-day trends), Bang Lang Dam status, 24h rain forecasts, terrain flood mapping, multi-pin family watch, offline voice briefings, shelters, and verified hotlines in one offline-resilient, 4-language (TH/EN/ZH/MS) app with Large Text Mode.

3. Setup & Testing Instructions:
- No login, demo credentials, or sample files needed. All 5 tabs work immediately with CDN-first live + bundled offline data.
- Switch to English: tap the top 15s setup banner or 5th tab ("ตั้งค่า") -> first dropdown ("ภาษา / Language") -> "🇬🇧 English".
- Map: tap district chips to drill down; tap "+ Add" to test Family Watchlist, offline voice briefing, and 1-tap Share Card; long-press inside Yala to test pin elevation comparison.
- Info: tap any rain bar to inspect; tap any station for the 7-day chart (24h/3d/7d).

4. External Services & Platforms:
- ThaiWater Public API v3 (HII — https://api-v3.thaiwater.net): Open data for 14 water stations, 7-day graphs, 87+ rain gauges, Bang Lang Dam.
- Open-Meteo Weather & GloFAS v4 (CC BY 4.0 — https://open-meteo.com): 24-72h rain & 7-day river discharge forecasts.
- GitHub Actions + Supabase Storage CDN: Signed read-only JSON snapshots updated every 10 min (CDN-first client fetch).
- Firebase Cloud Messaging (FCM)/APNs: Anonymous district-topic alerts (no accounts/PII).
- CARTO / OpenStreetMap public basemap tiles (ODbL / CC BY 3.0) with bounded local disk caching, plus standard external links (tel:, Google Maps Directions URL, official LINE/Facebook).

5. Regional Differences:
- Identical across all regions/countries with no geo-blocking. Monitoring data covers Yala Province, Thailand (code 95).

6. Regulated Industry / Third-Party Material:
- Independent public-interest civic tool — NOT an official government app or primary rescue channel. Clear in-app disclaimers direct emergencies to call 1784 (DDPM), 073-203559 (Yala DDPM), or 1669 (EMS).
- Uses only publicly open data (ThaiWater Public API v3 & Open-Meteo CC BY 4.0) with full attribution.
```
