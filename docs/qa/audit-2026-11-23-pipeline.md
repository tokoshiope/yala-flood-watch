# Independent QA / Security Audit — Data Pipeline + Alert Engine

- **วันที่:** 2026-11-23
- **ผู้ตรวจ:** Independent QA context (read-only)
- **ขอบเขต:** `backend/pipeline.py`, `backend/registry/*`, `mobile/app/lib/services/alert_engine.dart` + models/state, `backend/tests/`, `mobile/app/test/`, CI workflow
- **เอกสารอ้างอิง:** `docs/04-core-methodology.md` (formula_version=1), `docs/specs/spec-data-pipeline.md`, `docs/03-system-architecture.md` §7–8, `docs/tasks.md`, `AGENTS.md`
- **วิธีตรวจ:** อ่านโค้ด, รัน test suite จริง, ดึง ThaiWater API จริง (`province_code=95`) เทียบ registry, รัน probe แบบ monkeypatch โดยไม่แก้โค้ด

## ผลที่ยืนยันด้วย tool output

| คำสั่ง | ผล |
|---|---|
| `cd backend && .venv/bin/python -m pytest -q` | **8 passed** (exit 0) |
| `flutter analyze` | **No issues found** |
| `flutter test` | **30 passed** |
| ThaiWater API จริง `province_code=95` | **14 สถานี** — oldcode/พิกัด/ตลิ่ง/amphoe **ตรงกับ `stations.yaml` ทั้ง 14** (ไม่มี COORD_DIFF/BANK_DIFF) |
| probe stale (monkeypatch `now`) | **UTC: ข้อมูล 6h50m ยัง `stale=False`** (ICT: `True`) → บั๊ก timezone |
| probe hash | `content_hash` **ต่างกันเมื่อ `generated_at` ต่างกัน** → ไม่ deterministic ข้ามรอบ |
| probe race | รัน `main()` 2 ครั้งในวินาทีเดียว → **ชื่อไฟล์ snapshot ซ้ำกัน** (เขียนทับ) |

---

# VERDICT: **HOLD**

เหตุผล: fail-closed ของ pipeline (AC-2) **ใช้ไม่ได้จริงบน GitHub Actions (UTC)** และการเขียนไฟล์ output ไม่ atomic / ชื่อไฟล์ชนกัน — คลาดเคลื่อนจาก `docs/03 §8.2` ที่กำหนดไว้ชัดเจน. แก้ 2 BLOCKER + HIGH หลักก่อน Gate 3 / Beta.

---

## BLOCKER

### B-1 — การตรวจ stale/freshness ใช้ timezone ผิด → fail-closed AC-2 ไม่ทำงานบน CI (UTC)
**ไฟล์:** `backend/pipeline.py:63` (`now = now or datetime.now()`), `backend/pipeline.py:71-74` (`strptime(...)` ไม่มี tz + `now - obs_at`)
**ปัญหา:** `waterlevel_datetime` ของ ThaiWater เป็นเวลาท้องถิ่นไทย (`%Y-%m-%d %H:%M`, ICT=UTC+7) แต่ `now` คือเวลาเครื่อง server. GitHub Actions รันที่ UTC:
- ข้อมูลสด (28 นาที) → `now(UTC) - obs_at(ICT) ≈ -6h` → **negative → `stale=False`** (ถูกต้องโดยบังเอิญ)
- ข้อมูลชา 6 ชม. 50 นาที → ยัง `stale=False` → **ผ่านเกณฑ์ 30 นาที**
- ข้อมูลต้องชา > ~7 ชม. ถึงจะ `stale=True` → กฎ "ทุกสถานีเก่าเกิน 30 นาที → exit 1" ไม่ถูกเรียกจนกว่าต้นทางจะค้าง ~7 ชม.
**ผล:** ต้นทางค้าง/คืนข้อมูลเก่า แอพ/publisher ยังเห็น snapshot "สด" ไปอีกหลายชั่วโมง = เงื่อนไขไม่ปลอดภัย. ขัดกับ `docs/specs/spec-data-pipeline.md` AC-2 และ `docs/03-system-architecture.md` §8.2 "นาฬิกาเครื่อง: ใช้ fetched_at จาก API; ไม่ใช่เวลาเซิร์ฟเวอร์ pipeline"
**หลักฐาน:** probe — `server ICT now=22:58 -> True`, `server UTC now=15:58 -> False` (ข้อมูล 22:00), `6h50m old, UTC -> False`
**แนะนำ:** แปลง `obs_at` เป็น aware (สมมติ ICT/Asia-Bangkok) และเทียบกับ `datetime.now(timezone.utc)` อย่างซ้องอัตรา; หรือเทียบกับ `fetched_at` ที่ API ให้. เพิ่ม unit test ที่ freeze `now` เป็น UTC.

### B-2 — การเขียน output ไม่ปลอดภัยต่อ overlapping runs (ไม่ atomic, ชื่อไฟล์ชน, ไม่มี concurrency group)
**ไฟล์:** `backend/pipeline.py:158-161` (`ts = strftime("%Y%m%d-%H%M%S")` ความละเอียด 1 วินาที; `write_text` เขียนทับ `latest.json` โดยตรง), `backend/pipeline.py:162-171` (manifest เขียนทีหลัง), `.github/workflows/data-pipeline.yml` (cron `*/15`, ไม่มี `concurrency:`, ไม่มี lock)
**ปัญหา:** (1) รัน 2 รอบในวินาทีเดียว → ชื่อ `snapshot-<ts>.json` ซ้ำกัน → เขียนทับกัน; (2) `latest.json` เขียนแบบ truncate-then-write → reader/publisher อ่านได้ไฟล์เพี้ยน (torn JSON); (3) ไม่มี `concurrency` group / lock ตามที่ `docs/03 §8.2` กำหนด ("concurrency group หรือ lock ไฟล์", "atomic rename (เขียน tmp แล้ว rename)")
**ผล:** เมื่อ Phase 2 เริ่ม publish/latest ให้แอพ จะเกิด snapshot เพี้ยน/สลับ manifest เก่า-ใหม่. ขัด AC-2 (ห้ามเขียนข้อมูลเสียทับข้อมูลดี)
**หลักฐาน:** probe รัน `main()` 2 ครั้งด้วยนาฬิกาคงที่ → `files: ['latest.json','manifest.json','snapshot-20261123-120000.json']` (มี snapshot เดียว)
**แนะนำ:** เขียน `*.tmp` แล้ว `os.replace()`; ตั้ง `concurrency: {group: data-pipeline, cancel-in-progress: false}`; ใช้ timestamp ละเอียดกว่า 1 วิ (หรือ suffix ตาม content_hash); เขียน manifest เป็น atomic เช่นกัน.

---

## HIGH

### H-1 — Alert engine ไม่ได้ใช้สูตรหลักของ `docs/04` (ไม่มี W/H_normal, ไม่มี 5 ระดับ, ไม่มี flash override, ไม่มี hysteresis/cooldown)
**ไฟล์:** `mobile/app/lib/services/alert_engine.dart:19-55` (effectiveRisk), `alert_engine.dart:60-102` (evaluate), `mobile/app/lib/models/station.dart:139-159` (riskLevel), `mobile/app/lib/models/risk_level.dart:5-10`
**Mismatch กับ `docs/04-core-methodology.md`:**
| docs/04 | โค้ดจริง | สถานะ |
|---|---|---|
| Score = 0.5W+0.25R+0.15F+0.10C, level 1–5 | ไม่มี score เลย; map `situation_level` ตรง → 4 ระดับ (normal/watch/warning/danger) | ❌ ไม่มี level 5 (อันตราย/อพยพทันที) — คะแนน 60–79 กับ 80–100 ถูกรวมเป็น `danger` เดียว |
| W = (H−H_normal)/(H_bank−H_normal) | ใช้เกณฑ์งอก `remaining<=0.5→warning`, `<=2.0→watch` (station.dart:150-152) โดยไม่มี H_normal | ❌ |
| Flash flood override R≥0.7 +1, C≥0.6 +1 (สูงสุด +2) ใน 5 อำเภอ | ไม่มี; `risk_zone`/`isRiskAmphoe` ไม่ถูกใช้ใน evaluate | ❌ |
| Hysteresis 2 ชม., cooldown 30 นาที | ไม่มี; dedupe ด้วย id ที่มี **นาที** (`alert.dart:94-97`) → รอบใหม่นาทีใหม่สร้าง alert ซ้ำใหม่ทุกนาที | ❌ |
| ฝนอย่างเดียวไม่ push (§6) | `effectiveRisk` ยกระดับจาก `rain.suggestedLevel` แม้ situation=null และ W=0 (alert_engine.dart:46-54) → `evaluate` ยังสร้าง alert (watch ขึ้นไป) | ❌ |
| floor = max(level_from_score, situation) | ไม่มี score → ใช้ situation เป็น base โดยตรง (ใกล้เคียงแต่ไม่ใช้ floor จริง) | ⚠️ |
**หมายเหตุ:** `docs/04` หัวเอกสารระบุ prototype ใช้ `situation_level` เป็นหลัก และ `docs/tasks.md` ระบุ push/alert engine เป็น Phase 3 — แต่ QA ต้องบันทึกว่าสูตร formula_version=1 ยังไม่ถูกimplement. **เงื่อนไขผ่าน Gate 3:** ปรับ engine ให้คำนวณ score ได้ (หรือประกาศ formula_version=0/prototype อย่างชัดเจน + ลบ/ปิดเกณฑ์ที่ยังใช้ไม่ได้).

### H-2 — ไม่มี push notification จริงเลย (showFloodAlert ไม่ถูกเรียก)
**ไฟล์:** `mobile/app/lib/services/notification_service.dart:68` (นิยาม), `mobile/app/lib/state/alert_provider.dart` (ไม่มี call site), `mobile/app/lib/screens/settings_screen.dart:108-115` ("Push แจ้งเตือน / เปิดรับข้อความจาก ศูนย์ปภ.ยะลา")
**ปัญหา:** grep ทั้ง `lib/` พบ `showFloodAlert` เฉพาะตัวนิยาย — ไม่มีการเรียก. แอพจึงมีเพียง "รายการแจ้งเตือน" ในแท็บ ไม่มี local/push notification. ขัด `docs/04 §5.3/§6` และหัวเรื่อง Settings ที่อ้างถึงศูนย์ปภ.ยะลา
**ผล:** ผู้ใช้ไม่ได้รับการเตือนตามสัญญา; การตั้งค่า "Push" หลอกผู้ใช้
**แนะนำ:** เชื่อม `NotificationService.showFloodAlert` เข้า `AlertProvider` (เฉพาะ alert ใหม่ + ไม่ซ้ำตาม cooldown) หรือลบสวิตช์ Push ออกจนกว่าจะพร้อม

### H-3 — PDPA/Privacy: ไม่มี consent, เก็บ PII แบบ plaintext, ไม่มี "ลบข้อมูลของฉัน"
**ไฟล์:** `mobile/app/lib/screens/sos_screen.dart:38-79` (ขอ GPS ทันทีใน initState, ไม่มี consent), `sos_screen.dart:114-125` (บันทึก lat/lng/phone), `mobile/app/lib/services/local_store.dart:73-76` (`SharedPreferences.setString` plaintext), `mobile/app/lib/models/sos_request.dart:47-57` (มี phone + lat/lng)
**ปัญหา:** `docs/03 §7` กำหนด "ขอยินยอมก่อน มีหน้าจอ consent สำหรับตำแหน่ง/แจ้งเตือน ก่อนเก็บ" และ "มี 'ลบข้อมูลของฉัน'" — โค้ดไม่มีทั้งคู่. ข้อมูล SOS เก็บถาวร (แค่ cap 50 รายการ) ไม่มี retention/ลบ, ไม่เข้ารหัส
**ผล:** เกิน PDPA principle สำหรับ launch; แอพเก็บพิกัด+เบอร์โทรผู้ใช้แบบ sensitive โดยไม่มี disclosure
**แนะนำ:** เพิ่ม consent sheet ก่อนเปิดใช้ GPS/SOS; เพิ่มปุ่มลบประวัติ SOS; ระบุ retention; พิจารณา encrypt/ลดความแม่นยำพิกัดที่เก็บ

### H-4 — SOS ไม่ได้ส่งข้อมูลไปยังศูนย์ปภ.ยะลาจริง + ข้อความปุ่มชี้ไปทางส่ง
**ไฟล์:** `mobile/app/lib/screens/sos_screen.dart:95-136` (`_sendSos` เก็บ local + delay 400ms + snackbar ให้โทรเอง), `sos_screen.dart:217-220` ("ระบบจะแนบพิกัด GPS ของคุณไปด้วย"), `sos_screen.dart:438-443` (note เล็กเท่านั้นที่บอกว่ายังไม่ได้ส่ง)
**ปัญหา:** ปุ่มใหญ่ "กดขขอความช่วยเหลือ" + คำรอง "ระบบจะแนบพิกัด GPS ของคุณไปด้วย" อ่านแล้วเข้าใจว่ามีการส่ง; คำชี้แจงอยู่ใน note เล็กด้านล่าง. `docs/tasks.md` ระบุ SOS จำลองเป็น backlog — แต่ UI ไม่ได้ติ้ว label "จำลอง" ที่ปุ่ม
**ผล:** ความเข้าใจผิดของผู้ใช้ในสถานการณ์ฉุกเฉิน = ความเสี่ยงด้านความปลอดภัย; เสี่ยงกับ store review (ช่องทางกู้ภัย)
**แนะนำ:** ติ้ว "จำลอง/ยังไม่ส่งจริง" ที่ปุ่ม, ย้ำให้โทร 1677, และเพิ่ม disclaimer หน้าแรกตาม `AGENTS.md §5`

### H-5 — ไม่มี platform folders (android/ios) และไม่มี legal/privacy/store เอกสาร
**ไฟล์:** `mobile/app/` (ไม่มี `android/`, `ios/`), `docs/launch/` (ว่าง), `docs/legal/` (ว่าง), `docs/qa/` (ว่าง), `web/` (ว่าง)
**ปัญหา:** ไม่สามารถ build APK/IPA หรือตั้งค่า permission (`NSLocationWhenInUseUsageDescription`) ได้; ไม่มี privacy policy / terms / disclaimer สำหรับ store listing; `docs/tasks.md` ระบุเป็น Phase 3/5
**ผล:** ไม่พร้อม store submission; store compliance เบื้องต้นยังเป็น 0
**แนะนำ:** สร้าง platform folders + privacy/terms/disclaimer ก่อนประกาศใช้จริง; ใส่ disclaimer "ไม่ใช่ช่องทางกู้ภัยหลัก ให้โทร 1677" ในแอพหน้าแรกและ listing

---

## MEDIUM

### M-1 — Registry ไม่ถูกใช้ตาม `docs/04 §8.1`: ไม่ fallback ตลิ่ง และไม่บังคับว่า code ต้องมีใน registry
**ไฟล์:** `backend/pipeline.py:69` (`registry.get(oc, {})`), `pipeline.py:75-76` (bank อ่านจาก API เท่านั้น), `pipeline.py:102` (`risk_zone` = None เมื่อไม่พบ)
**หลักการที่ขัด:** `docs/04 §8.1` "ข้อมูลขาด ใช้ค่าจาก registry (เช่น ตลิ่ง)" และ "ห้ามเขียน snapshot ที่มี code ไม่มีใน registry"
**หลักฐาน:** probe — API `left_bank=null` แต่ registry `left_bank_m=13.85` → `bank_m=None, bank_missing=True`; สถานี `NEW999` ที่ไม่มีใน registry → ถูกเขียนทับได้ด้วย `risk_zone=None`
**ผล:** เสียสัญญาณ W เมื่อ API ขาดตลิ่ง; snapshot ปนสถานีนอก registry
**แนะนำ:** fallback ตลิ่งจาก registry + raise ValidationError เมื่อ code ไม่มีใน registry (ยกเว้น whitelist)

### M-2 — จุดอพยพ: registry กับแอพขัดกัน และ registry เป็น sample
**ไฟล์:** `backend/registry/shelters.yaml:2` (`status: sample_data_must_replace`, 4 แห่ง), `mobile/app/lib/screens/shelters_screen.dart:11-94` (hardcode `kSampleShelters` 8 แห่ง), `backend/pipeline.py:136` (เผย `shelters` เข้า snapshot)
**ปัญหา:** แอพไม่ได้อ่าน `shelters.yaml`/snapshot เลย — ข้อมูลสองชุดต่างกัน (เช่น ชื่อ "โรงเรียนบ้านตาเซะ" vs "วัดเมืองยะลา"; พิกัดต่าง) และทั้งคู่เป็น sample
**ผล:** ข้อมูลจุดอพยพผิดพลาดได้เมื่อผู้ใช้นำไปใช้จริง; drift ระหว่าง backend กับแอพ
**แนะนำ:** ให้แอพอ่าน shelters จาก snapshot/registry เดียวกัน; แก้เป็นข้อมูลจริงจาก ปภ.ยะลา ก่อน Beta

### M-3 — `content_hash` ไม่ deterministic ข้ามรอบ (มี `generated_at` อยู่ใน hash)
**ไฟล์:** `backend/pipeline.py:131` (`generated_at`), `pipeline.py:143-145` (hash ครอบ payload รวม `generated_at`)
**หลักฐาน:** probe — `generated_at` ต่างกัน → hash ต่างกัน. QA plan `spec-data-pipeline.md §5` คาด "hash ตรงกับ re-run"; `docs/03 §7` ใช้ `snapshot_hash` ตัดการซ้ำ → จะไม่มีทางตรงเลย
**ผล:** ใช้ dedupe/integrity cross-run ไม่ได้; hash เป็น "รหัสรอบ" ไม่ใช่ "รหัสเนื้อหา"
**แนะนำ:** ย้าย `generated_at` ออกจาก hash (hash เฉพาะ `stations`/`shelters`/formula_version) หรือ hash ก่อนใส่ `generated_at`

### M-4 — หน่วยงานฉุกเฉินเป็นค่า placeholder / ไม่ครบ
**ไฟล์:** `backend/registry/contacts.yaml:7-11` (`phone: '1677'`, `status: placeholder`), `contacts.yaml:12-28` (amphoe_centers ทั้ง 8 อำเภอ `phone: null`), `mobile/app/lib/config/app_config.dart:106-108` (ศูนย์ปภ.ยะลา = 1677)
**ปัญหา:** 1677 คือสายด่วนกรมปภ. ไม่ใช่เบอร์ตรงของ ศูนย์ปภ.ยะลา แต่แอพติ้ว "ศูนย์ปภ.ยะลา"; เบอร์อำเภอว่างทั้งหมด
**ผล:** ข้อมูลฉุกเฉินผิดชื่อ/ไม่ครบ — ความเสี่ยงสำหรับแอพภัยพิบัติ
**แนะนำ:** ยืนยันเบอร์จริงจาก ปภ.ยะลา ก่อน Beta; ผูกกับ `contacts.yaml` ผ่าน snapshot

### M-5 — Test ไม่เช็ค timezone/calendar boundary และ `test_main_success` พึ่ง API จริง
**ไฟล์:** `backend/tests/test_pipeline.py:93-100` (`P.main()` ไม่ mock เครือข่าย), `test_pipeline.py:81-83` (deep-copy ซึ่งคง `generated_at` เดิม → ผ่านโดยบังเอิญ), `test_pipeline.py:74-78` (bbox แบบแก้ค่าหลัง normalize)
**ปัญหา:** (1) test หลักพึ่ง network จริง → flaky/offline fail; (2) ไม่มี test สำหรับ UTC server, ซ้อน-ไฟล์, registry fallback, `situation_level` เป็น string/0/5, JSON เสีย, `result!=OK`, สถานีซ้ำ; (3) ไม่มี test flash override/hysteresis/cooldown/rain-only-push ใน `mobile/app/test/alert_engine_test.dart`
**ผล:** coverage claim ใน `spec-data-pipeline.md` AC-5 ("registry merge") ยังไม่เป็นจริง; บั๊ก B-1 รอดจาก test เพราะ test ไม่ได้ fix `now`
**แนะนำ:** เพิ่ม test ที่ monkeypatch `now` (UTC/ICT), และ test ที่ mock `fetch_raw`; เพิ่ม test ตาม test vectors ใน `docs/04 §7`

### M-6 — CI ไม่รัน pytest; cron ไม่มี concurrency; artifact name คงที่
**ไฟล์:** `.github/workflows/data-pipeline.yml` (มีเฉพาะ `python backend/pipeline.py`, ไม่มีขั้น test; `upload-artifact` name `yala-flood-snapshot` คงที่, retention 7 วัน)
**ผล:** การผ่าน test ไม่ถูกบังคับใน CI; artifact รอบใหม่ทับเก่า
**แนะนำ:** เพิ่ม step `pytest -q`, ตั้ง `concurrency`, เพิ่ม run-id/timestamp ใน artifact name

### M-7 — `fetch_raw` ไม่ตรวจ `result` และไม่ retry
**ไฟล์:** `backend/pipeline.py:50-58`
**ปัญหา:** ตรวจเฉพาะ `data` list; `result != "OK"` ที่มี data จะผ่าน; ไม่มี retry (mobile มี 2 ครั้ง) — timeout 20s เดียว. แก้ `result` ผิดพลาดชั่วคราว = fail-closed (ปลอดภัย) แต่กระบวนการค้าง
**แนะนำ:** ตรวจ `result`, เพิ่ม retry 2 ครั้งแบบ backoff (ทำให้ snapshot cadence 15 นาที สมเหตุสมผล)

---

## LOW

- **L-1** `situation_level` ที่เป็น string (`"3"`) หรือ `0`/`5` ถูกทำเป็น `None` (`pipeline.py:78`) — `int()` ไม่ถูกลองก่อน; `docs/04` ควร clamp 1–4. `pipeline.py:78`
- **L-2** `validate` ตรวจ lat/lon เฉพาะ `int/float` เท่านั้น (`pipeline.py:118`) — ถ้า API ส่ง string จะ fail-closed ทั้ง pipeline (api จริงส่ง number ปกติ). `pipeline.py:118-119`
- **L-3** ไม่มีการเช็คสถานีซ้ำ (`oldcode` ซ้ำ) → snapshot อาจมีซ้ำ; app แสดงซ้ำ. `pipeline.py:86-107`
- **L-4** `storage_percent`/`previous_msl` ใช้ truthiness → `0` กลายเป็น `None`. `pipeline.py:96-99`
- **L-5** `shelters.get("items")`/`contacts` ไม่มี schema validation — yaml เสีย = crash (fail-closed) แต่ error message ไม่คือ `ValidationError`. `pipeline.py:40-47,129-139`
- **L-6** `deep_link_service` นำทาง route จาก URI ภายนอกโดยไม่จำกัด (เช่น `yalaflood://station/<code>` ที่ code ไม่มี) — ตรวจแล้วมี fallback แต่ควร validate. `mobile/app/lib/services/deep_link_service.dart`
- **L-7** `mobile/app/pubspec.yaml:assets: - assets/` ชี้โฟลเดอร์ว่าง — build warning เป็นไปได้. `mobile/app/pubspec.yaml`
- **L-8** `settings_screen.dart:111` "เปิดรับข้อความจาก ศูนย์ปภ.ยะลา" ไม่ตรงกับความจริง (H-2). `settings_screen.dart:108-115`
- **L-9** `.env.example` มี `SUPABASE_SERVICE_ROLE_KEY`/`FCM_SERVER_KEY` เป็น placeholder (ไม่มี secret จริง) — ตรวจแล้วไม่พบ secret ใน repo (เฉพาะ `.env.example`, `.gitignore` ครอบ `.env*`). **ผ่าน.**

---

## สิ่งที่ตรวจแล้วผ่าน (PASS)

- **Registry vs API จริง 14 สถานี:** oldcode, lat/lon (ค่าต่าง < 0.0005), left_bank, amphoe **ตรงกับ `stations.yaml` ทุกสถานี**; ไม่มีสถานีตกหล่น/เกิน; 5 สถานีไม่มี `situation_level` (X.273, X.40A, BLGTU05, BLGTU06, X.77) และ 2 สถานีไม่มีตลิ่ง (BLGTU05, BLGTU06) — สอดคล้อง `docs/04 §11`
- **พิกัดใน bbox:** ครบ 14 สถานี อยู่ใน `YALA_BBOX (5.5, 7.2, 100.5, 101.9)`
- **Fail-closed พื้นฐาน:** API ว่าง/JSON เสีย/เน็ตขาด → exit 1, ไม่เขียนทับ (test ยืนยัน); `pytest 8/8`, `flutter test 30/30`, `flutter analyze` clean
- **Secrets:** ไม่พบ credential จริงใน repo; `.env.example` เป็น template เท่านั้น
- **Caching ฝั่งแอพ:** `ThaiWaterService` timeout/retry/fallback ถูกต้อง มี test ครอบคลุม
- **Methodology §2.1 (bank 0/ขาด):** `station.hasBank`/`riskLevel` ไม่ตีความสถานีที่ไม่มีตลิ่งผิดเป็นอันตราย (test BLGTU05 ผ่าน)

---

## สรุปตาม severity

| ระดับ | จำนวน | ID |
|---|---:|---|
| BLOCKER | 2 | B-1, B-2 |
| HIGH | 5 | H-1, H-2, H-3, H-4, H-5 |
| MEDIUM | 7 | M-1 … M-7 |
| LOW | 9 | L-1 … L-9 |

## เงื่อนไขก่อนกลับมา re-audit (อย่างน้อย)

1. แก้ B-1: aware timezone + test ที่ freeze `now` เป็น UTC (ต้องได้ `stale=True` เมื่อข้อมูลชา > 30 นาทีบน CI)
2. แก้ B-2: atomic write + `concurrency` group + test เขียนทับ/ซ้อน
3. ปรับ `content_hash` ให้ deterministic ข้ามรอบ (M-3) เพราะใช้ตัดซ้ำกับ push
4. ตัดสินใจ H-1: implement สูตร formula_version=1 หรือประกาศ prototype ไว้ชัด + ยกเลิกเกณฑ์ที่ยังไม่ได้ใช้
5. H-3/H-4: consent + disclaimer + ติ้ว SOS จำลอง ก่อนเปิดตัว
6. CI รัน pytest (M-6)

> หมายเหตุ: การตรวจนี้ **ไม่ได้แก้โค้ด** — เฉพาะเขียนรายงานฉบับนี้. หากต้องการให้แก้ข้อพบ ให้สร้าง task แยกตาม Gate 2.
