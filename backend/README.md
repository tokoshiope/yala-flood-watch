# Backend — Data Pipeline (Phase 1)

ดึงข้อมูลระดับน้ำจาก ThaiWater API (จ.ยะลา `province_code=95`) → normalize → validate (fail-closed) → snapshot JSON + `manifest.json`

## รันเอง
```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m pytest -q     # 8 tests
.venv/bin/python pipeline.py      # สร้าง output/latest.json + manifest.json
```

## ไฟล์
- `pipeline.py` — fetch/normalize/validate/build_snapshot/content_hash/main (exit 1 = fail-closed)
- `registry/stations.yaml|contacts.yaml|shelters.yaml` — registry แยก (ไม่ hardcode ในโค้ด)
- `tests/test_pipeline.py` — unit tests (normalize flags, validation, stale, bbox, hash, fail-closed)
- `.github/workflows/data-pipeline.yml` — cron ทุก 15 นาที + upload artifact

## หลักการ (docs/04-core-methodology.md)
- ข้อมูลเก่า >30 นาที → flag `stale`; ทุกสถานี stale → exit(1) ไม่เขียนทับ
- สถานีไม่มี `situation_level`/`bank` ยังอยู่ใน snapshot พร้อม flag
- content_hash = sha256 ของ snapshot canonical JSON
