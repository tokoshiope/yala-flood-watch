# 🌊 น้ำท่วมยะลา (Yala Flood Watch)

> **One Founder. AI-powered. Early Flood Warning Built for Every Household in Yala.**
> แอปพลิเคชันแจ้งเตือนภัยน้ำท่วมล่วงหน้า **เฉพาะจังหวัดยะลา (8 อำเภอ · `province_code=95`)** — พัฒนาเน้น **iOS เป็นอันดับแรก** ใช้งานฟรี 100% เชื่อมต่อฐานข้อมูลอุทกวิทยาและอุตุนิยมวิทยาจริง 5 แหล่ง พร้อมระบบประเมินเวลาน้ำเดินทางจากเขื่อนบางลาง 6–12 ชั่วโมง

> **คำชี้แจงด้านความปลอดภัย (Life-Safety Disclaimer):** แอปนี้เป็นระบบสนับสนุนการเฝ้าระวังและแจ้งเตือนภัยล่วงหน้าอิสระ **ไม่ใช่ช่องทางการแจ้งเหตุกู้ภัยหลักของทางราชการ** หากประสบเหตุฉุกเฉินหรือน้ำท่วมวิกฤต กรุณาโทร **1784** (สายด่วนนิรภัย กรม ปภ.), **073-203559** (ปภ.ยะลา), **073-212345** (ปภ.เทศบาลนครยะลา) หรือ **1669** (เจ็บป่วยฉุกเฉิน) ทันที

---

## การตัดสินใจที่ยืนยันแล้ว (Locked Founder Decisions — Gate 1 & Gate 2)

| หัวข้อ | การตัดสินใจ | อ้างอิง |
|---|---|---|
| **โครงสร้างทีม AI** | Solo Founder + AI Team (**Life-Safety Hybrid Pragmatic 5-Agent** — ดู [`AGENTS.md`](AGENTS.md)) | `DEC-009` |
| **ขอบเขตภูมิศาสตร์** | **เฉพาะจังหวัดยะลา 8 อำเภอ** (เมืองยะลา, รามัน, ยะหา, กรงปินัง, เบตง, บันนังสตา, ธารโต, กาบัง) · `Asia/Bangkok (UTC+7)` | `DEC-001` |
| **โมเดลการใช้งาน** | **ฟรี 100% ตลอดชีพ** ไม่มี IAP ไม่มีโฆษณา สถาปัตยกรรม Near-Zero Marginal Cost + Offline-First | `DEC-002` |
| **แพลตฟอร์ม & Stack** | **iOS-First ด้วย Flutter** (`mobile/app/ios/` พร้อมเปิดใน Xcode) + Python Multi-Source Pipeline + Interactive iOS Simulator Preview | `DEC-006`, `DEC-010` |
| **ฐานข้อมูลจริงที่เชื่อมต่อ** | **5 แหล่งข้อมูลเปิด ฟรี 100% ไม่ต้องใช้ API Key** (ThaiWater Waterlevel + Rain 87 สถานี + เขื่อนบางลาง + Open-Meteo 72h + GloFAS 7-Day) | `DEC-011` |
| **สูตรแจ้งเตือนล่วงหน้า** | **`formula_version = 2`**: `0.45W + 0.22R + 0.13F + 0.10D + 0.10C` + Rate-of-Rise `dH/dt` + Flash Flood Override + Dam Spillway 6–12 ชม. | `DEC-012` |
| **ข้อมูลฉุกเฉินยืนยันแล้ว** | **1784** (ปภ.ส่วนกลาง / LINE `@1784DDPM`), **073-203559** (ปภ.ยะลา), **073-212345** (เทศบาลนครยะลา), **1669**, **199**, **191**, **1677** (ร่วมด้วยช่วยกัน) | `DEC-013` |

---

## แหล่งข้อมูลจริงที่เชื่อมต่อ (5 Live Verified Data Sources)

| Tier | แหล่งข้อมูล | ขอบเขต จ.ยะลา | บทบาทในสูตร `formula_version = 2` |
|---|---|---|---|
| **Tier A (Official)** | **ThaiWater Water Level** (`public/waterlevel?province_code=95`) | **14 สถานีโทรมาตร** (สสน., กฟผ., ชป., พพภ.) | คำนวณ `W` (ระดับน้ำเทียบตลิ่ง) + `dH/dt` (อัตราการขึ้นของน้ำ) + `situation_level` floor |
| **Tier A (Official)** | **ThaiWater Real-Time Rain** (`public/rain_24h?province_code=95`) | **87 สถานีฝน ครบทั้ง 8 อำเภอ** (รวม อ.กาบัง 4 สถานี) | คำนวณ `R` (ฝนจริง 1 ชม. / 24 ชม.) + Flash Flood Override |
| **Tier A (Official)** | **ThaiWater Analyst Dam** (`analyst/dam` — เขื่อนบางลาง) | **กฟผ. รายชั่วโมง + ชป. รายวัน** | คำนวณ `D` (ความจุ %, น้ำไหลเข้า, ระบายออก, Spillway) → **เตือนภัยล่วงหน้า 6–12 ชม.** ถึงเมืองยะลา (X.40A) |
| **Tier B (Open Science)** | **Open-Meteo Weather Forecast** (`CC BY 4.0`) | พยากรณ์ฝนรายชั่วโมง **24–72 ชม.** ทั้ง 8 อำเภอ | คำนวณ `F` (พยากรณ์ฝน 24 ชม.) + แนวโน้มฝนสะสม 72 ชม. |
| **Tier B (Open Science)** | **Open-Meteo Flood / GloFAS v4** (`CC BY 4.0`) | ลุ่มน้ำปัตตานี (X.40A) & แม่น้ำสายบุรี (X.273) | พยากรณ์ปริมาณน้ำท่า (`m³/s`) ล่วงหน้า **7 วัน** เทียบค่าเฉลี่ย |

---

## โครงสร้างโปรเจกต์ (Repository Structure)

```text
Yala Flood/
├── AGENTS.md                                  # รัฐธรรมนูญทีม AI (Life-Safety Hybrid 5-Agent + 3 Human Gates)
├── README.md                                  # คู่มือหลักและคำสั่งรันระบบ
├── backend/
│   ├── pipeline.py                            # Multi-Source Fail-Closed Pipeline (5 Live APIs + Formula v2 + SHA-256 Manifest)
│   ├── registry/
│   │   ├── stations.yaml                      # ทะเบียน 14 สถานีวัดระดับน้ำ จ.ยะลา (Dynamic Registry)
│   │   ├── amphoes.yaml                       # ทะเบียน 8 อำเภอ พิกัด ประเภทภัย ระยะเวลาน้ำเดินทางเขื่อนบางลาง
│   │   ├── contacts.yaml                      # เบอร์ฉุกเฉินยืนยันแล้ว (1784, 073-203559, 073-212345 ฯลฯ)
│   │   └── shelters.yaml                      # ศูนย์พักพิง จ.ยะลา พร้อมป้ายสถานะการยืนยันพิกัด
│   ├── output/                                # latest.json + manifest.json (อัปเดตแบบ Atomic Write)
│   └── tests/test_pipeline.py                 # Hermetic Unit & Formula v2 Parity Tests (pytest)
├── mobile/
│   ├── app/                                   # Flutter iOS-First Application (lib/ + ios/ + assets/snapshots/ + test/)
│   └── preview/                               # Interactive iOS Prototype & Live Simulation Server (เปิดทดลองได้ทันที)
│       ├── serve.py                           # Python HTTP server + Live API Refresh endpoint (/api/refresh)
│       └── index.html                         # iPhone 16 Pro Interactive Simulator + 3 Flood Replay Scenarios
├── tools/dashboard/                           # Provincial Operations Dashboard (อ่านจาก latest.json อัตโนมัติ)
├── design/wireframes/                         # Wireframes 14 หน้าจอ
├── docs/
│   ├── 01-business-model-and-prd.md           # แผนสาธารณประโยชน์ & PRD สรุป
│   ├── 02-data-discovery-report.md            # รายงานตรวจสอบ API จริงทั้ง 5 แหล่ง
│   ├── 03-system-architecture.md              # สถาปัตยกรรม Fail-Closed + CDN + PDPA
│   ├── 04-core-methodology.md                 # สูตร Alert Score formula_version=2 + Test Vectors
│   ├── tasks.md                               # Living Task Board
│   ├── decisions.md                           # Living Decision Log (DEC-001..N)
│   ├── specs/                                 # Feature Specifications
│   └── qa/                                    # รายงาน Independent QA Audits (Context แยก)
└── .github/workflows/
    └── data-pipeline.yml                      # CI Tests + 15-min Scheduled Live Snapshot Cron
```

---

## คำสั่งทดสอบและใช้งาน (Quickstart)

### 1. รัน Multi-Source Pipeline เชื่อม 5 ฐานข้อมูลจริง + รัน Unit Tests
```bash
# สร้าง venv ครั้งแรก (ถ้ายังไม่มี)
python3 -m venv backend/.venv
backend/.venv/bin/pip install -r backend/requirements.txt

# รัน Unit Tests ทั้งหมด (Hermetic + Timezone UTC/ICT + Formula v2)
backend/.venv/bin/pytest -v backend/tests

# ดึงข้อมูลสดจริงจากทั้ง 5 ฐานข้อมูล → สร้าง backend/output/latest.json + อัปเดต offline snapshot ของแอป iOS
backend/.venv/bin/python backend/pipeline.py --sync-mobile-asset
```

### 2. เปิดโมเดลทดลอง iOS แบบ Interactive (เชื่อมต่อ 5 ฐานข้อมูลจริง + โหมดจำลองน้ำท่วม)
```bash
backend/.venv/bin/python mobile/preview/serve.py
# เปิดเบราว์เซอร์ที่ http://127.0.0.1:8785/
```
> กด **"ดึงข้อมูลสดจาก API จริง"** เพื่อยิงทั้ง 5 ฐานข้อมูลแบบเรียลไทม์ หรือสลับโหมดจำลองเหตุการณ์ (เขื่อนบางลางระบายน้ำ / ฝนหนักฉับพลัน อ.กาบัง / น้ำท่วมใหญ่ พ.ย. 2568) เพื่อทดสอบการแจ้งเตือนล่วงหน้าได้ทันที

### 3. ตรวจสอบและรันแอป Flutter iOS จริง (Flutter 3.50+ / Xcode)
```bash
export PATH="/Users/tokyo/flutter-sdk/bin:$PATH"
cd mobile/app
flutter pub get
flutter analyze
flutter test
# เปิดโปรเจกต์ iOS ใน Xcode เพื่อ Build ลง iPhone / TestFlight:
open ios/Runner.xcworkspace
```

---

## สถานะและแผนงาน (Roadmap)

- [x] **Phase 0: Inception & Baseline Docs** — PRD 1,011 บรรทัด, Wireframe 14 จอ, เอกสารฐาน 01–04
- [x] **Phase 1: Multi-Source Data Foundation (v2)** — เชื่อม 5 ฐานข้อมูลจริง (14 สถานีน้ำ + 87 สถานีฝน + เขื่อนบางลาง + Open-Meteo 72h + GloFAS 7d), สูตร `formula_version = 2`, Fail-Closed Pipeline + Unit Tests
- [x] **Phase 1.5: iOS-First App Core & Interactive Prototype** — สร้างโฟลเดอร์ `ios/` + Info.plist, แก้ `AlertEngine` v2 Parity, แก้เบอร์ฉุกเฉิน 1784/073-203559/073-212345, PDPA Consent & Delete Data, Interactive iOS Simulator Preview
- [ ] **Phase 2: Cloud Bridge & Legal Web** — เชื่อม Supabase Storage CDN, GitHub Pages Privacy/Terms, ยืนยันพิกัดจุดอพยพจริงจาก ปภ.ยะลา
- [ ] **Phase 3: iOS TestFlight Beta & Push (APNs/FCM)** — ทดสอบ Push จริงบน iPhone, Critical Alert / Silent Mode, แปลภาษามลายูท้องถิ่น (Yawi)
- [ ] **Phase 4: Independent QA Sign-Off & App Store Launch** — ผ่าน Gate 3 + ยื่น Apple App Store (ฟรี 100%)
