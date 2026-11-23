import json
import copy
import sys
from pathlib import Path
from datetime import datetime, timedelta

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pipeline as P


def _rows_sample(n=2, minutes_ago=5):
    rows = []
    for i in range(n):
        t = (datetime.now() - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%d %H:%M")
        rows.append({
            "id": 100 + i,
            "waterlevel_datetime": t,
            "waterlevel_msl": "10.5",
            "waterlevel_msl_previous": "10.4",
            "situation_level": 3,
            "storage_percent": "55.0",
            "station": {
                "tele_station_oldcode": f"T{i}",
                "tele_station_name": {"th": f"สถานี{i}"},
                "tele_station_lat": 6.5, "tele_station_long": 101.2, "left_bank": 13.85,
            },
            "geocode": {"amphoe_name": {"th": "เมืองยะลา"}},
            "river_name": {"th": "แม่น้ำปัตตานี"},
            "agency": {"agency_shortname": {"th": "สสน."}},
        })
    return rows


def _registry():
    with open(P.REGISTRY_DIR / "stations.yaml", encoding="utf-8") as f:
        return yaml.safe_load(f)["stations"]


def test_normalize_fields_and_flags():
    reg = _registry()
    regs = {"PAT002": reg["PAT002"]}
    rows = _rows_sample(1)
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[0]["situation_level"] = None
    rows[0]["station"]["left_bank"] = 0
    st, stats = P.normalize(rows, regs)
    s = st[0]
    assert s["name"] == "สถานี0"
    assert s["risk_zone"] == reg["PAT002"]["risk_zone"]
    assert s["situation_missing"] is True and s["situation_level"] is None
    assert s["bank_missing"] is True and s["bank_m"] is None
    assert stats["no_situation"] == 1 and stats["no_bank"] == 1


def test_validate_happy_pass():
    st, stats = P.normalize(_rows_sample(2), {"T0": {"risk_zone": "flash"}, "T1": {"risk_zone": "flash"}})
    P.validate(st, stats)  # no raise


def test_validate_empty_fails():
    with pytest.raises(P.ValidationError):
        P.validate([], {})


def test_validate_all_stale_fails_closed():
    st, stats = P.normalize(_rows_sample(2, minutes_ago=60), {"T0": {}, "T1": {}})
    with pytest.raises(P.ValidationError):
        P.validate(st, stats)


def test_validate_out_of_bbox_fails():
    st, stats = P.normalize(_rows_sample(1), {"T0": {}})
    st[0]["lat"] = 0
    with pytest.raises(P.ValidationError):
        P.validate(st, stats)


def test_hash_deterministic():
    p = P.build_snapshot([], {"emergency": {}}, {"items": []})
    assert P.content_hash(p) == P.content_hash(copy.deepcopy(p))


def test_main_fail_closed_on_bad_url(tmp_path, monkeypatch):
    monkeypatch.setattr(P, "API_URL", "http://127.0.0.1:9/none")
    monkeypatch.setattr(P, "OUT_DIR", tmp_path)
    assert P.main() == 1
    assert not (tmp_path / "latest.json").exists()  # ไม่เขียนทับ/สร้างไฟล์ว่าง


def test_main_success_writes_outputs(tmp_path, monkeypatch):
    monkeypatch.setattr(P, "OUT_DIR", tmp_path)
    rc = P.main()
    assert rc == 0
    latest = json.loads((tmp_path / "latest.json").read_text(encoding="utf-8"))
    man = json.loads((tmp_path / "manifest.json").read_text(encoding="utf-8"))
    assert man["count"] >= 1
    assert latest["content_hash"] == man["content_hash"]
    assert latest["province"]["code"] == "95"
