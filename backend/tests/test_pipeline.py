import copy
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import pipeline as P


def _rows_sample(n=2, minutes_ago=5, at=None):
    rows = []
    base = at or datetime.now(P.ICT)
    for i in range(n):
        t = (base - timedelta(minutes=minutes_ago)).strftime("%Y-%m-%d %H:%M")
        rows.append({
            "id": 100 + i,
            "waterlevel_datetime": t,
            "waterlevel_msl": "12.50",
            "waterlevel_msl_previous": "12.40",
            "situation_level": 3,
            "storage_percent": "55.0",
            "station": {
                "tele_station_oldcode": f"T{i}",
                "tele_station_name": {"th": f"สถานี{i}"},
                "tele_station_lat": 6.5,
                "tele_station_long": 101.2,
                "left_bank": 13.85,
            },
            "geocode": {"province_code": "95", "amphoe_name": {"th": "เมืองยะลา"}, "tumbon_name": {"th": "สะเตง"}},
            "river_name": {"th": "แม่น้ำปัตตานี"},
            "agency": {"agency_shortname": {"th": "สสน."}},
        })
    return rows


def _registry():
    with open(P.REGISTRY_DIR / "stations.yaml", encoding="utf-8") as f:
        return yaml.safe_load(f)["stations"]


def _amphoes_registry():
    with open(P.REGISTRY_DIR / "amphoes.yaml", encoding="utf-8") as f:
        return yaml.safe_load(f)["amphoes"]


# ── Formula v5 Core Test Vectors (TV5-1 through TV5-18 · 100% Parity with Dart) ──

@pytest.mark.parametrize(
    "case_id,kwargs,expected_level,expected_basis,expected_push",
    [
        # TV5-1: Dry day below watch -> Lv 1 ปกติ
        (
            "TV5-1_below_watch_normal",
            dict(level_msl=14.00, previous_msl=14.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False),
            1, "monitoring", False,
        ),
        # TV5-2: PAT002 calibrated watch=13.30 — normal controlled pool 12.85 m stays Lv 1 (eliminates dry-day false alarm!)
        (
            "TV5-2_pat002_controlled_pool_normal",
            dict(level_msl=12.85, previous_msl=12.85, bank_m=13.85, watch_m=13.30, critical_m=13.85, situation_level=4, stale=False),
            1, "monitoring", False,
        ),
        # TV5-3: Watch zone sideway (15.50 <= H < 16.00, dH = +0.02) -> Lv 2 เฝ้าระวัง
        (
            "TV5-3_watch_sideway",
            dict(level_msl=15.70, previous_msl=15.68, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            2, "water_stage", True,
        ),
        # TV5-4: Watch zone rising rapidly (dH = +0.16, time_to_bank = 5.0h <= 6h) -> Lv 4 proactive!
        (
            "TV5-4_watch_projected_overflow_6h",
            dict(level_msl=15.70, previous_msl=15.54, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            4, "water_stage", True,
        ),
        # TV5-5: Watch zone moderate rise (dH = +0.06, time_to_bank = 13.33h <= 24h) -> Lv 3 proactive!
        (
            "TV5-5_watch_projected_overflow_24h",
            dict(level_msl=15.70, previous_msl=15.64, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            3, "water_stage", True,
        ),
        # TV5-6: Mid zone steady (16.00 <= H < 16.25, dH = 0) -> Lv 3 เตือนภัย
        (
            "TV5-6_mid_steady",
            dict(level_msl=16.10, previous_msl=16.10, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            3, "water_stage", True,
        ),
        # TV5-7: Mid zone rapid surge (dH = +0.32) -> Lv 4 เตือนภัยสูง
        (
            "TV5-7_mid_rapid_surge",
            dict(level_msl=16.05, previous_msl=15.73, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            4, "water_stage", True,
        ),
        # TV5-8: High zone near bank (16.25 <= H < 16.50) -> Lv 4 เตือนภัยสูง
        (
            "TV5-8_high_near_bank",
            dict(level_msl=16.35, previous_msl=16.35, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            4, "water_stage", True,
        ),
        # TV5-9: Bank overflow (H >= crit) -> Lv 5 อันตราย
        (
            "TV5-9_bank_overflow",
            dict(level_msl=16.55, previous_msl=16.40, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=4, stale=False),
            5, "water_stage", True,
        ),
        # TV5-10: ThaiWater situation_level == 5 confirms overflow even if gauge below bank -> Lv 5
        (
            "TV5-10_agency_overflow_sit5",
            dict(level_msl=14.00, previous_msl=14.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=5, stale=False),
            5, "agency_overflow", True,
        ),
        # TV5-11: FOP045 datum_unverified=True with rapid surge dH=+0.32 -> NOT suppressed by 19.3m gap, Lv 3!
        (
            "TV5-11_fop045_datum_unverified_surge",
            dict(level_msl=6.12, previous_msl=5.80, bank_m=25.128, watch_m=23.20, critical_m=25.128, situation_level=None, stale=False, datum_unverified=True, is_flash_flood=True),
            3, "water_stage", True,
        ),
        # TV5-12: Bang Lang Dam spillway alone (dry river below watch) -> Lv 3 early warning
        (
            "TV5-12_dam_spillway_alone_lv3",
            dict(level_msl=12.00, previous_msl=12.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, dam_signal=1.0, dam_spillway_active=True, dam_inflow_daily_mcm=40.0, lead_time_hours="6–12 ชม."),
            3, "rain_dam_early_warning", True,
        ),
        # TV5-13: Bang Lang Dam Critical Compound (spillway + inflow >= 90 MCM/day) -> Lv 4 proactive!
        (
            "TV5-13_dam_critical_compound_lv4",
            dict(level_msl=12.00, previous_msl=12.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, dam_signal=1.0, dam_spillway_active=True, dam_inflow_daily_mcm=110.0, lead_time_hours="6–12 ชม."),
            4, "rain_dam_early_warning", True,
        ),
        # TV5-14: Bang Lang Dam Elevated (storage >= 75% / D=0.45) -> Lv 2 early watch
        (
            "TV5-14_dam_elevated_lv2",
            dict(level_msl=12.00, previous_msl=12.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, dam_signal=0.45, dam_spillway_active=False, lead_time_hours="6–12 ชม."),
            2, "rain_dam_early_warning", True,
        ),
        # TV5-15: Extreme Urban Pluvial (Nov 2025 benchmark: rain_72h=334, api_7d=150, forecast_6h=35) -> Lv 4 proactive (NEVER Lv 5 without water!)
        (
            "TV5-15_extreme_urban_pluvial_lv4",
            dict(level_msl=13.00, previous_msl=13.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, rain_1h_mm=30.0, rain_24h_mm=160.0, rain_72h_mm=334.0, api_7d_mm=150.0, forecast_6h_mm=35.0, is_urban_basin=True),
            4, "rain_dam_early_warning", True,
        ),
        # TV5-16: Heavy Urban Pluvial (below extreme threshold) -> Lv 3
        (
            "TV5-16_heavy_urban_pluvial_lv3",
            dict(level_msl=13.00, previous_msl=13.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, rain_1h_mm=50.0, rain_24h_mm=145.0, api_7d_mm=95.0, is_urban_basin=True),
            3, "rain_dam_early_warning", True,
        ),
        # TV5-17: Extreme Flash Flood (อ.กาบัง 0 water gauges: rain_24h=220, api_7d=135, rain_1h=35) -> Lv 4 proactive!
        (
            "TV5-17_kabang_extreme_flash_lv4",
            dict(level_msl=None, previous_msl=None, bank_m=None, situation_level=None, stale=False, rain_1h_mm=35.0, rain_24h_mm=220.0, api_7d_mm=135.0, forecast_6h_mm=30.0, is_flash_flood=True, has_water_gauge=False),
            4, "rain_dam_early_warning", True,
        ),
        # TV5-18: Moderate rain without wet soil/water -> Lv 1 monitoring, no false push
        (
            "TV5-18_moderate_rain_no_false_alarm",
            dict(level_msl=12.00, previous_msl=12.00, bank_m=16.50, watch_m=15.50, critical_m=16.50, situation_level=3, stale=False, rain_1h_mm=20.0, rain_24h_mm=45.0, api_7d_mm=30.0, is_urban_basin=True),
            1, "monitoring", False,
        ),
    ],
)
def test_formula_v5_vectors(case_id, kwargs, expected_level, expected_basis, expected_push):
    res = P.compute_alert_v5(**kwargs)
    assert res["formula_version"] == 5
    assert res["level"] == expected_level, f"{case_id}: expected level {expected_level}, got {res['level']} (flags={res['flags']})"
    assert res["alert_basis"] == expected_basis, f"{case_id}: expected basis {expected_basis}, got {res['alert_basis']}"
    assert res["should_push"] is expected_push, f"{case_id}: expected push {expected_push}, got {res['should_push']}"


def test_layer2_terrain_exposure_matrix_v5():
    # Basin Lv 1 -> all zones Lv 1 (zero dry-day false alarms!)
    assert P.evaluate_terrain_exposure_level(1, "A") == 1
    assert P.evaluate_terrain_exposure_level(1, "B") == 1
    assert P.evaluate_terrain_exposure_level(1, "C") == 1
    # Basin Lv 2 -> A:2, B:1, C:1
    assert P.evaluate_terrain_exposure_level(2, "A") == 2
    assert P.evaluate_terrain_exposure_level(2, "B") == 1
    assert P.evaluate_terrain_exposure_level(2, "C") == 1
    # Basin Lv 3 -> A:3, B:2, C:1
    assert P.evaluate_terrain_exposure_level(3, "A") == 3
    assert P.evaluate_terrain_exposure_level(3, "B") == 2
    assert P.evaluate_terrain_exposure_level(3, "C") == 1
    # Basin Lv 4 -> A:4, B:3, C:1
    assert P.evaluate_terrain_exposure_level(4, "A") == 4
    assert P.evaluate_terrain_exposure_level(4, "B") == 3
    assert P.evaluate_terrain_exposure_level(4, "C") == 1
    # Basin Lv 5 -> A:5, B:4 (escalates to 5 only if overflow_depth >= rel_height), C:1
    assert P.evaluate_terrain_exposure_level(5, "A") == 5
    assert P.evaluate_terrain_exposure_level(5, "B", overflow_depth_m=0.8, rel_height_m=2.5) == 4
    assert P.evaluate_terrain_exposure_level(5, "B", overflow_depth_m=2.6, rel_height_m=2.5) == 5
    assert P.evaluate_terrain_exposure_level(5, "C") == 1


# ── Normalization, Registry Fallback, Anomaly & Deduplication ───────────────

def test_normalize_registry_bank_fallback_and_anomaly():
    reg = _registry()
    regs = {"PAT002": reg["PAT002"], "BLGTU05": reg["BLGTU05"]}
    rows = _rows_sample(2)
    # PAT002 has left_bank_m=13.85 in registry; API sends 0 -> must fallback to registry!
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[0]["station"]["left_bank"] = 0
    rows[0]["situation_level"] = None
    rows[0]["storage_percent"] = "-0.31"  # sensor anomaly
    # BLGTU05 has left_bank_m=null in registry and 0 in API -> bank_missing=True
    rows[1]["station"]["tele_station_oldcode"] = "BLGTU05"
    rows[1]["station"]["left_bank"] = 0
    rows[1]["situation_level"] = None

    st, stats = P.normalize(rows, regs)
    assert st[0]["bank_m"] == 13.85
    assert st[0]["bank_source"] == "registry_fallback"
    assert st[0]["bank_missing"] is False
    assert st[0]["storage_anomaly"] is True and st[0]["storage_percent"] is None
    assert st[1]["bank_m"] is None and st[1]["bank_missing"] is True
    assert stats["bank_from_registry"] == 1
    assert stats["storage_anomaly"] == 1
    assert stats["no_bank"] == 1


def test_normalize_skips_duplicate_station_codes():
    rows = _rows_sample(2)
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[1]["station"]["tele_station_oldcode"] = "PAT002"
    st, stats = P.normalize(rows, _registry())
    assert len(st) == 1
    assert stats["duplicates_skipped"] == 1


def test_stale_check_is_timezone_aware_under_utc_clock():
    # Observed at 10:00 ICT (03:00 UTC); CI server clock is 04:30 UTC (11:30 ICT -> 90m old -> STALE)
    now_utc = datetime(2026, 11, 24, 4, 30, tzinfo=timezone.utc)
    rows = _rows_sample(1)
    rows[0]["waterlevel_datetime"] = "2026-11-24 10:00"
    st, stats = P.normalize(rows, {"T0": {}}, now=now_utc)
    assert st[0]["stale"] is True
    assert st[0]["age_minutes"] == 90.0
    assert stats["stale"] == 1


def test_stale_check_fresh_under_utc_clock():
    # Observed at 10:00 ICT (03:00 UTC); CI server clock is 03:20 UTC (10:20 ICT -> 20m old -> FRESH)
    now_utc = datetime(2026, 11, 24, 3, 20, tzinfo=timezone.utc)
    rows = _rows_sample(1)
    rows[0]["waterlevel_datetime"] = "2026-11-24 10:00"
    st, stats = P.normalize(rows, {"T0": {}}, now=now_utc)
    assert st[0]["stale"] is False
    assert st[0]["age_minutes"] == 20.0
    assert stats["stale"] == 0


# ── Validation & Fail-Closed Tests ──────────────────────────────────────────

def test_validate_empty_fails():
    with pytest.raises(P.ValidationError):
        P.validate([], {})


def test_validate_all_stale_fails_closed():
    st, stats = P.normalize(_rows_sample(2, minutes_ago=95), {"T0": {}, "T1": {}})
    with pytest.raises(P.ValidationError):
        P.validate(st, stats)


def test_validate_out_of_bbox_fails():
    st, stats = P.normalize(_rows_sample(1), {"T0": {}})
    st[0]["lat"] = 13.75  # Bangkok, not Yala!
    with pytest.raises(P.ValidationError):
        P.validate(st, stats)


def test_kabang_covered_in_amphoe_summary_without_water_station():
    amphoes_reg = _amphoes_registry()
    rain_by_amp = {"กาบัง": {"gauge_count": 4, "fresh_gauge_count": 4, "max_rain_1h_mm": 52.0, "avg_rain_1h_mm": 30.0, "max_rain_24h_mm": 110.0, "avg_rain_24h_mm": 75.0, "stale": False, "latest_observed_at": "2026-11-24 15:00"}}
    wx_by_amp = {"กาบัง": {"forecast_6h_mm": 25.0, "forecast_24h_mm": 75.0, "forecast_72h_mm": 120.0, "max_prob_24h_pct": 90, "hourly_next_24h": [], "daily_3d": []}}
    summaries = P.build_amphoe_summaries(amphoes_reg, [], rain_by_amp, wx_by_amp, None)
    assert len(summaries) == 8
    kabang = next(a for a in summaries if a["amphoe"] == "กาบัง")
    assert kabang["water_station_count"] == 0
    assert kabang["assessment"]["level"] >= 3
    assert kabang["assessment"]["should_push"] is True


def test_deterministic_content_hash_excludes_volatile_fields():
    reg = _registry()
    t1 = datetime(2026, 11, 24, 15, 30, tzinfo=P.ICT)
    t2 = datetime(2026, 11, 24, 15, 35, tzinfo=P.ICT)
    rows = _rows_sample(2, at=datetime(2026, 11, 24, 15, 25, tzinfo=P.ICT))
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[1]["station"]["tele_station_oldcode"] = "PAT001"
    s1, _ = P.normalize(rows, reg, now=t1)
    s2, _ = P.normalize(copy.deepcopy(rows), reg, now=t2)
    assert s1[0]["age_minutes"] != s2[0]["age_minutes"]
    b1 = P.build_snapshot(s1, {"emergency": []}, {"items": []}, source_health={"thaiwater_waterlevel": {"status": "ok", "latency_ms": 100}})
    b2 = P.build_snapshot(s2, {"emergency": []}, {"items": []}, source_health={"thaiwater_waterlevel": {"status": "ok", "latency_ms": 950}})
    assert P.content_hash(b1) == P.content_hash(b2)
    assert "generated_at" not in b1


def test_single_null_stale_station_does_not_fail_healthy_province():
    fixed = datetime(2026, 11, 24, 15, 30, tzinfo=P.ICT)
    rows = _rows_sample(2, minutes_ago=10, at=fixed)
    rows[1]["waterlevel_msl"] = None
    rows[1]["waterlevel_datetime"] = "2026-11-24 12:00"  # stale + null on 1 sensor only
    st, stats = P.normalize(rows, {"T0": {}, "T1": {}}, now=fixed)
    P.validate(st, stats)  # should NOT fail-closed whole province
    assert st[1].get("unusable_sensor") is True


def test_main_fail_closed_preserves_existing_snapshot(tmp_path, monkeypatch):
    existing = tmp_path / "latest.json"
    existing.write_text('{"preserved": true}', encoding="utf-8")
    monkeypatch.setattr(P, "fetch_raw", lambda url=None: (_ for _ in ()).throw(P.ValidationError("API down")))
    monkeypatch.setattr(P, "OUT_DIR", tmp_path)
    rc, payload = P.run_pipeline()
    assert rc == 1 and payload is None
    assert json.loads(existing.read_text(encoding="utf-8")) == {"preserved": True}


def test_main_graceful_degradation_when_secondary_sources_fail(tmp_path, monkeypatch):
    fixed = datetime(2026, 11, 24, 14, 0, tzinfo=P.ICT)
    rows = _rows_sample(2, at=fixed)
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[1]["station"]["tele_station_oldcode"] = "PAT001"
    monkeypatch.setattr(P, "fetch_raw", lambda url=None: rows)
    monkeypatch.setattr(P, "fetch_rain_raw", lambda url=None: (_ for _ in ()).throw(RuntimeError("rain timeout")))
    monkeypatch.setattr(P, "fetch_banglang_dam", lambda url=None: (_ for _ in ()).throw(RuntimeError("dam timeout")))
    monkeypatch.setattr(P, "fetch_open_meteo_weather", lambda reg: (_ for _ in ()).throw(RuntimeError("wx timeout")))
    monkeypatch.setattr(P, "fetch_glofas_flood", lambda: (_ for _ in ()).throw(RuntimeError("glofas timeout")))
    monkeypatch.setattr(P, "OUT_DIR", tmp_path)

    rc, payload = P.run_pipeline(now=fixed)
    assert rc == 0 and payload is not None
    assert len(payload["degraded_sources"]) == 4
    assert len(payload["amphoes"]) == 8
    man = json.loads((tmp_path / "manifest.json").read_text(encoding="utf-8"))
    assert man["content_hash"] == payload["content_hash"]
    assert man["formula_version"] == 5


def test_contacts_registry_has_verified_1784_and_yala_ddpm():
    _, _, contacts, _ = P.load_registry()
    by_id = {c["id"]: c for c in contacts["emergency"]}
    assert by_id["ddpm_1784"]["phone"] == "1784"
    assert by_id["yala_ddpm"]["phone"] == "073-203559"
    assert by_id["yala_municipality"]["phone"] == "073-212345"
    assert by_id["volunteer_1677"]["phone"] == "1677"
    assert "ร่วมด้วยช่วยกัน" in by_id["volunteer_1677"]["name"]


def test_yala_geojson_covers_exact_8_amphoes_matching_registry():
    geo = json.loads((P.REGISTRY_DIR / "yala_amphoes.geojson").read_text(encoding="utf-8"))
    geo_names = {f["properties"]["amphoe_th"] for f in geo["features"]}
    reg_names = set(_amphoes_registry().keys())
    assert len(geo_names) == 8
    assert geo_names == reg_names


def test_subdistricts_and_villages_with_real_elevation_msl():
    subs = json.loads((P.REGISTRY_DIR / "yala_subdistricts.geojson").read_text(encoding="utf-8"))
    assert len(subs["features"]) == 58
    sub_amphoes = {f["properties"]["amphoe_th"] for f in subs["features"]}
    assert sub_amphoes == set(_amphoes_registry().keys())
    assert all(f["properties"].get("elevation_msl") is not None for f in subs["features"])

    vils = json.loads((P.REGISTRY_DIR / "yala_villages.json").read_text(encoding="utf-8"))
    assert vils["total_villages"] == 449
    assert len(vils["villages"]) == 449
    assert all(v.get("elevation_msl") is not None for v in vils["villages"])


def test_contacts_social_links_and_historical_shelters_v3():
    _, _, contacts, shelters = P.load_registry()
    by_id = {c["id"]: c for c in contacts["emergency"]}
    assert by_id["ddpm_1784"]["line_url"] == "https://line.me/R/ti/p/@1784DDPM"
    assert by_id["ddpm_1784"]["facebook_url"] == "https://www.facebook.com/DDPMNews"
    assert by_id["yala_municipality"]["line_url"] == "https://line.me/R/ti/p/@yalacity"
    assert by_id["medical_1669"]["facebook_url"] == "https://www.facebook.com/thainems"
    assert by_id["yala_hospital"]["facebook_url"] == "https://www.facebook.com/pryalahospital"
    assert by_id["volunteer_1677"]["facebook_url"] == "https://www.facebook.com/ruamduay"

    items = shelters["items"]
    assert {s["amphoe"] for s in items} == set(_amphoes_registry().keys())
    assert not any("พิกัดโดยประมาณ" in (s.get("address", "") + s.get("notes", "")) for s in items)
    non_city = [s for s in items if s["amphoe"] != "เมืองยะลา"]
    assert len(non_city) >= 7
    assert all(s.get("is_historical_unconfirmed") is True for s in non_city)
    assert all("อ้างอิงจากข้อมูลเดิม รอยืนยัน" in s.get("notes", "") for s in non_city)


def test_publish_supabase_dry_run_and_tamper_fail_closed(tmp_path):
    import publish_supabase as PUB

    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    rows = _rows_sample(2, at=fixed)
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[1]["station"]["tele_station_oldcode"] = "PAT001"
    reg, amps, contacts, shelters = P.load_registry()
    st, _ = P.normalize(rows, reg, now=fixed)
    amp_sum = P.build_amphoe_summaries(amps, st, {}, {}, None)
    body = P.build_snapshot(st, contacts, shelters, amphoes=amp_sum)
    digest = P.content_hash(body)
    payload = {**body, "generated_at": fixed.isoformat(), "content_hash": digest}
    (tmp_path / "latest.json").write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    (tmp_path / "manifest.json").write_text(
        json.dumps({"content_hash": digest, "count": len(st), "amphoe_count": 8}, ensure_ascii=False),
        encoding="utf-8",
    )
    assert PUB.publish(tmp_path, dry_run=True) == 0

    # Tamper latest.json -> must fail-closed (exit 1)
    tampered = {**payload, "province": {"code": "95", "name": "TAMPERED"}}
    (tmp_path / "latest.json").write_text(json.dumps(tampered, ensure_ascii=False), encoding="utf-8")
    assert PUB.publish(tmp_path, dry_run=True) == 1


def test_notify_fcm_topic_parity_cooldown_and_tamper_fail_closed(tmp_path):
    import notify_fcm as N

    # 1. All 8 amphoes map to valid ASCII FCM topics matching Dart NotificationService
    reg_amphoes = set(_amphoes_registry().keys())
    assert set(N.AMPHOE_TOPIC_MAP.keys()) == reg_amphoes
    for topic in [N.TOPIC_ALL_YALA, *N.AMPHOE_TOPIC_MAP.values()]:
        assert topic.isascii() and " " not in topic and ":" not in topic

    # 2. Build citizen-friendly messages (zero formula/score jargon) + 30m cooldown + escalation
    snap = {
        "province": {"code": "95", "name": "ยะลา"},
        "amphoes": [
            {
                "amphoe": "เมืองยะลา",
                "assessment": {
                    "level": 3,
                    "score": 48.5,
                    "should_push": True,
                    "action_th": "ยกของมีค่าขึ้นที่สูง เตรียมถุงยังชีพ",
                    "lead_time_hours": "6–12 ชม.",
                },
            },
            {
                "amphoe": "เบตง",
                "assessment": {
                    "level": 2,
                    "score": 24.0,
                    "should_push": False,
                    "action_th": "ฝนอย่างเดียวไม่ Push",
                },
            },
        ],
    }
    t0 = 1_700_000_000.0
    msgs = N.build_fcm_messages(snap, {}, now_ts=t0)
    topics = {m["message"]["topic"] for m in msgs}
    assert topics == {"yala_flood_mueang_yala", "yala_flood_all"}
    for m in msgs:
        text = m["message"]["notification"]["title"] + m["message"]["notification"]["body"]
        assert "formula" not in text.lower()
        assert "48.5" not in text

    # Same level within 15 minutes -> suppressed by 30-min cooldown
    state = {
        "yala_flood_mueang_yala": {"level": 3, "sent_at": t0},
        "yala_flood_all": {"level": 3, "sent_at": t0},
    }
    assert N.build_fcm_messages(snap, state, now_ts=t0 + 15 * 60) == []

    # Escalation to level 4 after 5 minutes -> bypasses cooldown immediately
    snap["amphoes"][0]["assessment"]["level"] = 4
    esc_msgs = N.build_fcm_messages(snap, state, now_ts=t0 + 5 * 60)
    assert len(esc_msgs) == 2

    # HIGH-2 regression: After 2-hour hysteresis window expires, a prior Level 5 event
    # MUST NOT permanently suppress a new Level 2–3 flood warning in a later storm.
    old_lv5_state = {"yala_flood_mueang_yala": {"level": 5, "sent_at": t0}}
    snap["amphoes"][0]["assessment"]["level"] = 3
    later_msgs = N.build_fcm_messages(snap, old_lv5_state, now_ts=t0 + N.HYSTERESIS_SECONDS + 60)
    assert any(m["message"]["topic"] == "yala_flood_mueang_yala" for m in later_msgs)

    # Reconcile state prunes topics once they return to Level 1 (normal)
    normal_snap = {
        "province": {"code": "95", "name": "ยะลา"},
        "amphoes": [{"amphoe": "เมืองยะลา", "assessment": {"level": 1, "should_push": False}}],
    }
    pruned = N.reconcile_state(normal_snap, old_lv5_state, [], now_ts=t0 + 600)
    assert "yala_flood_mueang_yala" not in pruned

    # 3. Fail-closed on tampered latest.json
    (tmp_path / "latest.json").write_text(json.dumps(snap), encoding="utf-8")
    (tmp_path / "manifest.json").write_text(json.dumps({"content_hash": "0" * 64}), encoding="utf-8")
    assert N.main(["--snapshot-dir", str(tmp_path), "--dry-run"]) == 1


def test_normalize_preserves_thaiwater_situation_level_5_and_4_correctly():
    """QA BLOCKER-1 regression: normalize() MUST preserve ThaiWater situation_level=5 (overflow)."""
    fixed = datetime(2026, 11, 27, 8, 0, tzinfo=P.ICT)
    rows = _rows_sample(2, at=fixed)
    # Row 0: unbanked BLGTU05 with ThaiWater situation_level=5 -> MUST reach Lv 5 agency_overflow
    rows[0]["station"]["tele_station_oldcode"] = "BLGTU05"
    rows[0]["station"]["left_bank"] = 0
    rows[0]["station"]["right_bank"] = 0
    rows[0]["station"]["min_bank"] = 0
    rows[0]["situation_level"] = 5
    # Row 1: banked PAT001 below watch with situation_level=4 -> MUST stay Lv 1 normal
    rows[1]["station"]["tele_station_oldcode"] = "PAT001"
    rows[1]["waterlevel_msl"] = "36.01"
    rows[1]["waterlevel_msl_previous"] = "36.00"
    rows[1]["station"]["left_bank"] = 38.678
    rows[1]["situation_level"] = 4

    stations, _ = P.normalize(rows, _registry(), now=fixed)
    by_code = {s["oldcode"]: s for s in stations}
    assert by_code["BLGTU05"]["situation_level"] == 5
    assert by_code["BLGTU05"]["assessment"]["level"] == 5
    assert by_code["BLGTU05"]["assessment"]["alert_basis"] == "agency_overflow"
    assert by_code["PAT001"]["situation_level"] == 4
    assert by_code["PAT001"]["assessment"]["level"] == 1
    assert by_code["PAT001"]["assessment"]["alert_basis"] == "monitoring"


def test_notify_fcm_tags_rain_dam_early_warning_on_amphoe_and_provincial_topics():
    """QA MEDIUM-3 regression: both amphoe and yala_flood_all topics carry basis tag and lead time."""
    import notify_fcm

    snap = {
        "amphoes": [
            {
                "amphoe": "เมืองยะลา",
                "assessment": {
                    "level": 3,
                    "should_push": True,
                    "alert_basis": "rain_dam_early_warning",
                    "action_th": "ยกของขึ้นที่สูง",
                    "lead_time_hours": "6–12 ชม.",
                },
            }
        ]
    }
    msgs = notify_fcm.build_fcm_messages(snap, state={}, now_ts=1_700_000_000.0)
    by_topic = {m["message"]["topic"]: m["message"]["notification"] for m in msgs}
    assert "yala_flood_mueang_yala" in by_topic
    assert "yala_flood_all" in by_topic
    for topic in ("yala_flood_mueang_yala", "yala_flood_all"):
        assert "(เตือนภัยล่วงหน้าจากฝน/เขื่อน)" in by_topic[topic]["title"]
        assert "6–12 ชม." in by_topic[topic]["body"]


def test_banglang_high_inflow_surge_triggers_early_dam_signal():
    # Nov 2024: storage still 51%, release normal, but inflow surges to 130.98 MCM/day -> D = 0.75!
    dam = {"storage_percent": 51.0, "released_daily_mcm": 8.0, "spilled_mcm": 0.0, "inflow_daily_mcm": 130.98}
    d_sig, spilled, lead, inflow = P.compute_dam_signal(dam, "เมืองยะลา")
    assert d_sig == 0.75
    assert spilled is False
    assert lead == "6–12 ชม."
    assert inflow == 130.98


def test_station_registry_real_names_and_rid8_thresholds():
    reg = _registry()
    assert reg["X.273"]["display_name"] == "บ้านปายอยือนิ"
    assert reg["X.273"]["short_name_th"] == "บ้านปายอยือนิ"
    assert reg["X.40A"]["watch_m"] == 15.50
    assert reg["X.40A"]["critical_m"] == 16.50
    assert reg["X.77"]["watch_m"] == 38.00
    assert reg["X.77"]["critical_m"] == 39.70
    assert reg["PAT002"]["watch_m"] == 13.30
    assert reg["FOP045"].get("datum_unverified") is True
    for code, item in reg.items():
        assert item.get("short_name_th") and not item["display_name"].endswith(" "), f"Bad name for {code}"
        assert item.get("name_en") and item.get("name_zh") and item.get("name_ms"), f"Missing i18n for {code}"


def _ring_area(ring):
    s = 0.0
    for i in range(len(ring) - 1):
        s += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1]
    return abs(s) / 2.0


def _geom_area(geom):
    if geom["type"] == "Polygon":
        return _ring_area(geom["coordinates"][0])
    return sum(_ring_area(poly[0]) for poly in geom["coordinates"])


def test_curved_gis_boundaries_zero_overlap_and_dem_exposure_zones():
    # Subdistricts must be high-res curved GeoThai DOPA polygons (avg >= 80 vertices)
    amps = json.loads((P.REGISTRY_DIR / "yala_amphoes.geojson").read_text(encoding="utf-8"))
    subs = json.loads((P.REGISTRY_DIR / "yala_subdistricts.geojson").read_text(encoding="utf-8"))
    verts = [len(f["geometry"]["coordinates"][0]) for f in subs["features"]]
    assert len(subs["features"]) == 58
    assert sum(verts) / len(verts) >= 80.0

    # Exact 0.00% amphoe vs sum(subdistricts) area conservation (LL-005 regression!)
    amp_areas = {f["properties"]["amphoe_th"]: _geom_area(f["geometry"]) for f in amps["features"]}
    sub_areas_by_amp = {}
    sub_areas_by_key = {}
    for f in subs["features"]:
        p = f["properties"]
        a = _geom_area(f["geometry"])
        sub_areas_by_amp[p["amphoe_th"]] = sub_areas_by_amp.get(p["amphoe_th"], 0.0) + a
        sub_areas_by_key[(p["amphoe_th"], p["tumbon_th"])] = a
    for amp_name, aa in amp_areas.items():
        err_pct = abs(sub_areas_by_amp[amp_name] - aa) / aa * 100.0
        assert err_pct < 0.01, f"Amphoe/subdistrict mismatch for {amp_name}: {err_pct:.4f}%"

    # Exact <0.05% tambon vs sum(village_zones) area conservation (LL-006 regression!)
    vz = json.loads((P.REGISTRY_DIR / "yala_village_zones.geojson").read_text(encoding="utf-8"))
    assert len(vz["features"]) >= 430
    vz_areas_by_key = {}
    for f in vz["features"]:
        p = f["properties"]
        k = (p["amphoe_th"], p["tumbon_th"])
        vz_areas_by_key[k] = vz_areas_by_key.get(k, 0.0) + _geom_area(f["geometry"])
        assert p.get("exposure_zone") in ("A", "B", "C")
    for k, sa in sub_areas_by_key.items():
        if k in vz_areas_by_key:
            err_pct = abs(vz_areas_by_key[k] - sa) / sa * 100.0
            assert err_pct < 0.05, f"Tambon/village-zone mismatch for {k}: {err_pct:.4f}%"

    # 449 villages all tagged with exposure_zone A/B/C
    vils = json.loads((P.REGISTRY_DIR / "yala_villages.json").read_text(encoding="utf-8"))["villages"]
    assert len(vils) == 449
    zones = {v.get("exposure_zone") for v in vils}
    assert zones == {"A", "B", "C"}

    # DEM grid & topographic elevation zones exist, cover all 8 amphoes, and carry A/B/C tags
    dem = json.loads((P.REGISTRY_DIR / "yala_dem_grid.json").read_text(encoding="utf-8"))
    assert dem["province_code"] == "95"
    assert dem["rows"] > 50 and dem["cols"] > 40
    non_null = sum(1 for row in dem["values"] for v in row if v is not None)
    assert non_null >= 1500

    ez = json.loads((P.REGISTRY_DIR / "yala_elevation_zones.geojson").read_text(encoding="utf-8"))
    assert len(ez["features"]) >= 100
    assert {f["properties"]["amphoe_th"] for f in ez["features"]} == set(_amphoes_registry().keys())
    assert all(f["properties"].get("exposure_zone") in ("A", "B", "C") for f in ez["features"])


def test_rain_degraded_outage_triggers_sensor_gap_fallback_in_normalize():
    # MEDIUM-1 regression: when entire thaiwater_rain_24h feed fails (amphoe_rain={}),
    # normalize(..., rain_degraded=True) MUST trigger rain_sensor_gap + Open-Meteo past_24h fallback.
    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    rows = _rows_sample(1, at=fixed)
    rows[0]["station"]["tele_station_oldcode"] = "X.40A"
    rows[0]["waterlevel_msl"] = "14.50"
    rows[0]["waterlevel_msl_previous"] = "14.40"
    rows[0]["situation_level"] = None
    wx = {
        "เมืองยะลา": {
            "past_24h_mm": 160.0,
            "observed_rain_72h_mm": 260.0,
            "api_7d_mm": 140.0,
            "forecast_6h_mm": 35.0,
            "forecast_24h_mm": 90.0,
            "forecast_72h_mm": 150.0,
        }
    }
    st, _ = P.normalize(
        rows,
        _registry(),
        now=fixed,
        rain_gauges=[],
        amphoe_rain={},
        weather_by_amphoe=wx,
        rain_degraded=True,
    )
    assert st[0]["rain_sensor_gap"] is True
    assert st[0]["rain_24h_mm"] == 160.0
    assert st[0]["assessment"]["confidence"] == "medium"
    assert st[0]["assessment"]["level"] >= 3


def test_normalize_fop045_datum_unverified_and_pat002_watch_calibration():
    fixed = datetime(2026, 11, 27, 12, 0, tzinfo=P.ICT)
    rows = _rows_sample(2, at=fixed)
    # PAT002 controlled pool at 12.85 m stays Lv 1 normal with watch=13.30 m
    rows[0]["station"]["tele_station_oldcode"] = "PAT002"
    rows[0]["station"]["left_bank"] = 13.85
    rows[0]["waterlevel_msl"] = "12.85"
    rows[0]["waterlevel_msl_previous"] = "12.84"
    rows[0]["situation_level"] = 4
    # FOP045 with datum_unverified=True and rapid rise dH=+0.35 escalates to Lv 3 (not suppressed by 19.3m bank gap)
    rows[1]["station"]["tele_station_oldcode"] = "FOP045"
    rows[1]["station"]["left_bank"] = 25.128
    rows[1]["waterlevel_msl"] = "6.15"
    rows[1]["waterlevel_msl_previous"] = "5.80"
    rows[1]["situation_level"] = None
    rows[1]["geocode"]["amphoe_name"] = {"th": "กรงปินัง"}

    st, _ = P.normalize(rows, _registry(), now=fixed)
    by_code = {s["oldcode"]: s for s in st}
    assert by_code["PAT002"]["assessment"]["level"] == 1
    assert by_code["FOP045"]["datum_unverified"] is True
    assert by_code["FOP045"]["remaining_to_bank_m"] is None
    assert by_code["FOP045"]["assessment"]["level"] == 3
    assert by_code["FOP045"]["assessment"]["confidence"] == "medium"


def test_publish_supabase_rejects_non_https_before_sending_service_key(monkeypatch):
    import publish_supabase as PUB

    called = {"count": 0}
    monkeypatch.setattr(
        PUB.requests,
        "post",
        lambda *a, **kw: called.__setitem__("count", called["count"] + 1),
    )
    monkeypatch.setenv("SUPABASE_URL", "http://insecure.supabase.co")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "super-secret-key")
    rc = PUB.publish(P.OUT_DIR, dry_run=False)
    assert rc == 1
    assert called["count"] == 0
    assert PUB._purge_expired_reports("http://insecure.supabase.co", "super-secret-key") is None
    assert called["count"] == 0


def test_agency_update_interval_and_tele_station_id():
    assert P.infer_update_interval_minutes("สสน.") == 10
    assert P.infer_update_interval_minutes("พพภ") == 10
    assert P.infer_update_interval_minutes("กฟผ.") == 60
    assert P.infer_update_interval_minutes("ชป.") == 60
    assert P.infer_update_interval_minutes("unknown") == 60

    reg, _, _, _ = P.load_registry()
    now = datetime(2026, 11, 26, 23, 50, tzinfo=P.ICT)
    row = _rows_sample(n=1, minutes_ago=10, at=now)[0]
    row["station"]["tele_station_oldcode"] = "PAT002"
    row["station"]["id"] = 901
    row["agency"] = {"agency_shortname": {"th": "สสน."}}
    stations, _ = P.normalize([row], reg, now=now)
    assert stations[0]["tele_station_id"] == 901
    assert stations[0]["update_interval_minutes"] == 10
    assert stations[0]["station_type"] == "tele_waterlevel"


def test_fetch_station_history_7d_filters_nulls_and_downsamples(monkeypatch):
    # Simulate 300 ten-minute points (>220 threshold) plus trailing None values
    base = datetime(2026, 11, 24, 0, 0, tzinfo=P.ICT)
    graph_data = []
    for i in range(300):
        dt_str = (base + timedelta(minutes=10 * i)).strftime("%Y-%m-%d %H:%M")
        val = None if i >= 298 else round(12.0 + i * 0.002, 3)
        graph_data.append({"datetime": dt_str, "value": val, "discharge": None})

    monkeypatch.setattr(
        P,
        "_http_get_json",
        lambda url, params=None, timeout=12: {"result": "OK", "data": {"graph_data": graph_data}},
    )
    stations = [{"oldcode": "PAT002", "tele_station_id": 901, "station_type": "tele_waterlevel"}]
    hist = P.fetch_station_history_7d(stations, base + timedelta(days=2), days=7)
    assert "PAT002" in hist
    pts = hist["PAT002"]
    assert all(pt["v"] is not None for pt in pts)
    # Must downsample to hourly points plus the final non-null reading
    assert len(pts) < 100
    assert pts[-1]["t"] == (base + timedelta(minutes=10 * 297)).strftime("%Y-%m-%d %H:%M")


def test_build_amphoe_summaries_attaches_watch_villages():
    reg, amphoes_reg, _, _ = P.load_registry()
    villages = P.load_villages_registry()
    assert len(villages) >= 400
    now = datetime(2026, 11, 26, 23, 50, tzinfo=P.ICT)
    row = _rows_sample(n=1, minutes_ago=50, at=now)[0]
    row["station"]["tele_station_oldcode"] = "X.40A"
    row["station"]["left_bank"] = 16.5
    row["waterlevel_msl"] = "14.50"
    row["waterlevel_msl_previous"] = "14.20"
    stations, _ = P.normalize([row], reg, now=now)
    summaries = P.build_amphoe_summaries(
        {"เมืองยะลา": amphoes_reg["เมืองยะลา"]},
        stations,
        {},
        {},
        None,
        villages=villages,
    )
    watch = summaries[0]["watch_areas"]
    assert len(watch) == 6
    # Sorted by lowest margin_m relative to river water level (14.5 m MSL)
    margins = [w["margin_m"] for w in watch]
    assert margins == sorted(margins)
    assert all(w["name_th"] and w["tumbon_th"] for w in watch)


def test_snapshot_sources_hint_is_10_minutes():
    _, _, contacts, shelters = P.load_registry()
    snap = P.build_snapshot([], contacts, shelters)
    assert snap["sources"]["refresh_interval_hint_minutes"] == 10
    assert "waterlevel_graph" in snap["sources"]["thaiwater_waterlevel_graph"]


def test_geojson_zero_self_intersection_and_zero_pairwise_crossings():
    """LOW-2 permanent regression: every amphoe, tambon, and village-zone polygon ring
    MUST have 0 self-intersections and 0 pairwise interior edge crossings."""
    from collections import defaultdict

    def ccw(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    def strictly_cross(a, b, c, d):
        if max(a[0], b[0]) <= min(c[0], d[0]) or max(c[0], d[0]) <= min(a[0], b[0]):
            return False
        if max(a[1], b[1]) <= min(c[1], d[1]) or max(c[1], d[1]) <= min(a[1], b[1]):
            return False
        d1, d2 = ccw(a, b, c), ccw(a, b, d)
        d3, d4 = ccw(c, d, a), ccw(c, d, b)
        return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and (
            (d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)
        )

    def ring_segs(ring):
        pts = ring[:-1] if len(ring) > 1 and ring[0] == ring[-1] else ring
        return [(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts))]

    for fname in ("yala_amphoes.geojson", "yala_subdistricts.geojson", "yala_village_zones.geojson"):
        doc = json.loads((P.REGISTRY_DIR / fname).read_text(encoding="utf-8"))
        for f in doc["features"]:
            g = f["geometry"]
            rings = [g["coordinates"][0]] if g["type"] == "Polygon" else [p[0] for p in g["coordinates"]]
            for r in rings:
                pts = r[:-1] if len(r) > 1 and r[0] == r[-1] else r
                n = len(pts)
                assert n >= 3, f"{fname} degenerate ring"
                for i in range(n):
                    a, b = pts[i], pts[(i + 1) % n]
                    for j in range(i + 2, n):
                        if i == 0 and j == n - 1:
                            continue
                        assert not strictly_cross(a, b, pts[j], pts[(j + 1) % n]), (
                            f"Self-intersection in {fname}: {f['properties']}"
                        )

    # Zero intra-tambon pairwise edge crossings across all 444 village zones
    vils = json.loads((P.REGISTRY_DIR / "yala_village_zones.geojson").read_text(encoding="utf-8"))["features"]
    by_tam = defaultdict(list)
    for f in vils:
        by_tam[(f["properties"]["amphoe_th"], f["properties"]["tumbon_th"])].append(f)
    for tk, flist in by_tam.items():
        seg_lists = []
        bboxes = []
        for f in flist:
            g = f["geometry"]
            rings = [g["coordinates"][0]] if g["type"] == "Polygon" else [p[0] for p in g["coordinates"]]
            segs = [s for r in rings for s in ring_segs(r)]
            seg_lists.append(segs)
            xs = [p[0] for a, b in segs for p in (a, b)]
            ys = [p[1] for a, b in segs for p in (a, b)]
            bboxes.append((min(xs), max(xs), min(ys), max(ys)))
        for i in range(len(flist)):
            x1, x2, y1, y2 = bboxes[i]
            for j in range(i + 1, len(flist)):
                ox1, ox2, oy1, oy2 = bboxes[j]
                if x2 <= ox1 or ox2 <= x1 or y2 <= oy1 or oy2 <= y1:
                    continue
                for a, b in seg_lists[i]:
                    for c, d in seg_lists[j]:
                        assert not strictly_cross(a, b, c, d), f"Village crossing in {tk}"


# ── P0–P2 Ops Hardening, Durable FCM State & Historical Backtest Tests ──


def test_ops_signal_enforces_https_only():
    # Plain HTTP URLs must be rejected silently (never leak secrets or make plaintext ops calls)
    assert P._send_ops_signal(
        ok=True,
        summary="test",
        heartbeat_url="http://insecure.example.com/ping",
        alert_webhook_url="",
    ) is False
    assert P._send_ops_signal(
        ok=False,
        summary="fail",
        heartbeat_url="http://insecure.example.com/ping",
        alert_webhook_url="http://insecure.example.com/hook",
    ) is False


def test_notify_fcm_supabase_state_enforces_https():
    import notify_fcm as NF

    assert NF.load_state_from_supabase(
        supabase_url="http://insecure.example.com",
        service_key="secret",
    ) is None
    assert NF.save_state_to_supabase(
        {"yala_flood_all": {"level": 3, "sent_at": 1000}},
        supabase_url="http://insecure.example.com",
        service_key="secret",
    ) is False


def test_historical_backtest_2567_2568_passes_with_zero_false_alarms():
    import backtest_yala_2567_2568 as BT

    report = BT.run_backtest()
    assert report["all_passed"] is True
    assert report["pod"] == 1.0
    assert report["far"] == 0.0
    assert report["csi"] == 1.0
    assert report["total"] >= 9

