#!/usr/bin/env python3
"""Yala Flood App — Data Pipeline (Phase 1)

Fetch ThaiWater API (province_code=95) -> normalize -> validate -> snapshot.
Fail-closed: ห้ามเขียนทับไฟล์ดีด้วยข้อมูลว่าง/เสียหากต้นทางล่ม (exit 1)
formula_version=1 (docs/04-core-methodology.md)
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import requests
import yaml

BASE_DIR = Path(__file__).resolve().parent
REGISTRY_DIR = BASE_DIR / "registry"
OUT_DIR = BASE_DIR / "output"

PROVINCE_CODE = "95"
API_URL = f"https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code={PROVINCE_CODE}"
FORMULA_VERSION = 1
HTTP_TIMEOUT = 20
MAX_STALE_MINUTES = 30
YALA_BBOX = (5.5, 7.2, 100.5, 101.9)  # lat_min, lat_max, lon_min, lon_max
ICT = ZoneInfo("Asia/Bangkok")  # ข้อมูล ThaiWater ระบุเวลาตาม ICT (UTC+7) แบบ naive


def _ict(dt: datetime) -> datetime:
    """ถ้า datetime ไม่มี tz ให้สมมติเป็น ICT เสมอ (กัน timezone bug บน GitHub Actions UTC)"""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=ICT)
    return dt.astimezone(ICT)


class ValidationError(Exception):
    pass


def _th(v) -> str:
    return (v or {}).get("th") if isinstance(v, dict) else (v or "")


def load_registry():
    with open(REGISTRY_DIR / "stations.yaml", encoding="utf-8") as f:
        stations = yaml.safe_load(f)["stations"]
    with open(REGISTRY_DIR / "contacts.yaml", encoding="utf-8") as f:
        contacts = yaml.safe_load(f)
    with open(REGISTRY_DIR / "shelters.yaml", encoding="utf-8") as f:
        shelters = yaml.safe_load(f)
    return stations, contacts, shelters


def fetch_raw(url: str | None = None) -> list[dict]:
    url = url or API_URL
    r = requests.get(url, headers={"User-Agent": "yala-flood-pipeline/1.0"}, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    payload = r.json()
    rows = payload.get("data")
    if not isinstance(rows, list) or len(rows) == 0:
        raise ValidationError("API คืนข้อมูลว่างหรือผิดโครงสร้าง (fail-closed)")
    return rows


def normalize(rows: list[dict], registry: dict, now: datetime | None = None) -> tuple[list[dict], dict]:
    """แปลง JSON เป็น snapshot records + stats; ตั้ง flag stale/situation_missing/bank_missing"""
    now = now or datetime.now(ICT)
    out, stats = [], {"stale": 0, "no_situation": 0, "no_bank": 0, "unknown_registry": 0}
    for r in rows:
        st = r.get("station") or {}
        geo = r.get("geocode") or {}
        oc = st.get("tele_station_oldcode") or ""
        reg = registry.get(oc)
        if reg is None:
            stats["unknown_registry"] += 1
        reg = reg or {}
        try:
            obs_at = _ict(datetime.strptime(r["waterlevel_datetime"], "%Y-%m-%d %H:%M"))
        except (KeyError, ValueError, TypeError):
            obs_at = None
        stale = (obs_at is None) or ((now - obs_at).total_seconds() > MAX_STALE_MINUTES * 60)
        bank = st.get("left_bank")
        bank = float(bank) if bank and float(bank) > 0 else None
        situation = r.get("situation_level")
        situation = int(situation) if situation in (1, 2, 3, 4) else None
        if stale:
            stats["stale"] += 1
        if situation is None:
            stats["no_situation"] += 1
        if bank is None:
            stats["no_bank"] += 1
        lvl = r.get("waterlevel_msl")
        rec = {
            "id": r.get("id"),
            "oldcode": oc,
            "name": _th(st.get("tele_station_name")) or reg.get("display_name") or oc,
            "river": _th(r.get("river_name")),
            "amphoe": _th(geo.get("amphoe_name")),
            "tumbon": _th(geo.get("tumbon_name")),
            "lat": st.get("tele_station_lat"),
            "lon": st.get("tele_station_long"),
            "level_msl": float(lvl) if lvl not in (None, "") else None,
            "previous_msl": float(r["waterlevel_msl_previous"]) if r.get("waterlevel_msl_previous") else None,
            "bank_m": bank,
            "situation_level": situation,
            "storage_percent": float(r["storage_percent"]) if r.get("storage_percent") else None,
            "observed_at": r.get("waterlevel_datetime"),
            "agency": _th((r.get("agency") or {}).get("agency_shortname")),
            "risk_zone": reg.get("risk_zone", "unknown"),
            "registry_known": reg != {},
            "stale": stale,
            "situation_missing": situation is None,
            "bank_missing": bank is None,
        }
        out.append(rec)
    return out, stats


def validate(stations: list[dict], stats: dict) -> None:
    """เงื่อนไขบังคับก่อนเขียนไฟล์ — ล้มเหลวใดๆ คือ ValidationError (fail-closed)"""
    if not stations:
        raise ValidationError("ไม่มีสถานีให้เขียน (fail-closed)")
    for s in stations:
        if not s.get("name"):
            raise ValidationError(f"สถานี {s.get('oldcode')} ไม่มีชื่อ")
        if not isinstance(s.get("lat"), (int, float)) or not isinstance(s.get("lon"), (int, float)):
            raise ValidationError(f"สถานี {s['name']} พิกัดไม่ถูกต้อง")
        lat, lon = s["lat"], s["lon"]
        if not (YALA_BBOX[0] <= lat <= YALA_BBOX[1] and YALA_BBOX[2] <= lon <= YALA_BBOX[3]):
            raise ValidationError(f"พิกัดสถานี {s['name']} นอกขอบเขตยะลา ({lat},{lon})")
        if s["level_msl"] is None and s["stale"]:
            raise ValidationError(f"สถานี {s['name']} ไม่มีระดับน้ำและข้อมูลเก่าเกินเกณฑ์")
    if stats["stale"] == len(stations):
        raise ValidationError("ทุกสถานีเก่าเกิน 30 นาที — ต้นทางอาจล่ม (fail-closed)")


def build_snapshot(stations: list[dict], contacts: dict, shelters: dict) -> dict:
    """สร้าง snapshot body โดยไม่มี generated_at/content_hash (เพื่อให้ hash deterministic)"""
    return {
        "formula_version": FORMULA_VERSION,
        "province": {"code": PROVINCE_CODE, "name": "ยะลา"},
        "source": {"thaiwater_api": API_URL, "refresh_interval_hint_minutes": 15},
        "stations": sorted(stations, key=lambda s: (s["amphoe"], s["name"])),
        "shelters": shelters.get("items", []),
        "shelters_status": shelters.get("status"),
        "contacts": contacts,
    }


def content_hash(body: dict) -> str:
    canon = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def _atomic_write(path: Path, text: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    try:
        registry_st, contacts, shelters = load_registry()
        rows = fetch_raw()
        stations, stats = normalize(rows, registry_st)
        validate(stations, stats)
        body = build_snapshot(stations, contacts, shelters)
        digest = content_hash(body)
        payload = {**body, "generated_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                   "content_hash": digest}
        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        snap_path = OUT_DIR / f"snapshot-{ts}-{digest[:8]}.json"
        snap_path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
        _atomic_write(OUT_DIR / "latest.json", json.dumps(payload, ensure_ascii=False, indent=1))
        manifest = {
            "generated_at": payload["generated_at"],
            "count": len(stations),
            "content_hash": digest,
            "snapshot": snap_path.name,
            "source": payload["source"],
            "formula_version": FORMULA_VERSION,
            "stats": stats,
        }
        _atomic_write(OUT_DIR / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=1))
        print(f"OK {len(stations)} stations hash={digest[:12]} stale={stats['stale']} "
              f"no_situation={stats['no_situation']} no_bank={stats['no_bank']} "
              f"unknown_registry={stats['unknown_registry']}")
        return 0
    except ValidationError as e:
        print(f"PIPELINE_FAIL_CLOSED: {e}", file=sys.stderr)
        return 1
    except Exception as e:  # network/IO/parse — ห้ามทับข้อมูลดี
        print(f"PIPELINE_FAIL_CLOSED: unexpected error: {e!r}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
