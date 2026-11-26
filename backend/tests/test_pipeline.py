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


# ── Formula v2 Exact Test Vectors (TV2-1 through TV2-9) ─────────────────────

@pytest.mark.parametrize(
    "case_id,kwargs,expected_score,expected_level,expected_push",
    [
        (
            "TV2-1_normal",
            dict(
                level_msl=12.05, previous_msl=12.05, bank_m=13.85, h_normal_30d=11.85,
                situation_level=1, stale=False, rain_1h_mm=6.0, forecast_24h_mm=12.0,
                dam_signal=0.0, dam_spillway_active=False, community_reports_60m=0,
                is_flash_flood=False,
            ),
            8.0, 1, False,
        ),
        (
            "TV2-2_bank_full",
            dict(
                level_msl=13.85, previous_msl=13.85, bank_m=13.85,
                situation_level=3, stale=False,
            ),
            45.0, 3, True,
        ),
        (
            "TV2-3_max_crisis",
            dict(
                level_msl=14.0, previous_msl=13.65, bank_m=13.85,
                situation_level=4, stale=False, rain_1h_mm=70.0, forecast_24h_mm=140.0,
                dam_signal=1.0, dam_spillway_active=True, community_reports_60m=6,
                is_flash_flood=True,
            ),
            100.0, 5, True,
        ),
        (
            "TV2-4_rain_only_no_push",
            dict(
                level_msl=10.0, previous_msl=10.0, bank_m=13.85,
                situation_level=None, stale=False, rain_1h_mm=54.0, forecast_24h_mm=36.0,
                is_flash_flood=False,
            ),
            23.7, 2, False,
        ),
        (
            "TV2-5_banglang_spillway_early_warning",
            dict(
                level_msl=12.25, previous_msl=12.25, bank_m=13.85,
                situation_level=1, stale=False, rain_1h_mm=12.0, forecast_24h_mm=24.0,
                dam_signal=1.0, dam_spillway_active=True, lead_time_hours="6–12 ชม.",
            ),
            26.0, 3, True,
        ),
        (
            "TV2-6_kabang_no_water_gauge_extreme_rain",
            dict(
                level_msl=None, previous_msl=None, bank_m=None,
                situation_level=None, stale=False, rain_1h_mm=51.0, forecast_24h_mm=72.0,
                is_flash_flood=True, has_water_gauge=False,
            ),
            26.5, 3, True,
        ),
        (
            "TV2-7_flash_rain_and_community",
            dict(
                level_msl=10.0, previous_msl=10.0, bank_m=13.85,
                situation_level=None, stale=False, rain_1h_mm=45.0, community_reports_60m=3,
                is_flash_flood=True,
            ),
            22.5, 4, True,
        ),
        (
            "TV2-8_rapid_rise_bonus",
            dict(
                level_msl=12.85, previous_msl=12.50, bank_m=13.85,
                situation_level=2, stale=False, is_flash_flood=True,
            ),
            29.3, 3, True,
        ),
        (
            "TV2-9_no_bank_situation_floor",
            dict(
                level_msl=100.5, previous_msl=100.5, bank_m=None,
                situation_level=4, stale=False,
            ),
            45.0, 4, True,
        ),
        (
            "TV2-10_ieee754_boundary_39_95_to_40_0",
            dict(
                level_msl=10.0, previous_msl=10.0, bank_m=13.85,
                situation_level=None, stale=False,
                rain_1h_mm=42.0, forecast_24h_mm=42.0,
                dam_signal=1.0, dam_spillway_active=False,
                community_reports_60m=5, is_flash_flood=False,
            ),
            40.0, 3, True,
        ),
    ],
)
def test_formula_v2_vectors(case_id, kwargs, expected_score, expected_level, expected_push):
    res = P.compute_alert_v2(**kwargs)
    assert res["score"] == expected_score, f"{case_id}: expected score {expected_score}, got {res['score']}"
    assert res["level"] == expected_level, f"{case_id}: expected level {expected_level}, got {res['level']}"
    assert res["should_push"] is expected_push, f"{case_id}: expected push {expected_push}, got {res['should_push']}"


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
    assert man["formula_version"] == 3


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


# ── Formula v3 Exact Parity Vectors & Historical 2024/2025 Backtests ────────

@pytest.mark.parametrize(
    "case_id,kwargs,expected_score,expected_level,expected_push,expected_mech,expected_conf",
    [
        (
            "TV3-1_normal",
            dict(
                level_msl=14.2, previous_msl=14.2, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=1, stale=False, rain_1h_mm=3.0, forecast_24h_mm=11.0,
            ),
            5.1, 1, False, "monitoring", "high",
        ),
        (
            "TV3-2_nov2025_x40a_overflow_no_sit",
            dict(
                level_msl=17.74, previous_msl=17.50, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=None, stale=False, rain_1h_mm=5.0, rain_24h_mm=20.0,
                is_urban_basin=True,
            ),
            40.9, 5, True, "riverine_overflow", "high",
        ),
        (
            "TV3-3_nov2025_urban_3day_333mm_low_dam",
            dict(
                level_msl=14.5, previous_msl=14.4, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=None, stale=False, rain_24h_mm=155.0, rain_72h_mm=333.8,
                api_7d_mm=140.0, forecast_6h_mm=35.0, dam_signal=0.0, is_urban_basin=True,
            ),
            45.1, 3, True, "urban_pluvial", "high",
        ),
        (
            "TV3-4_nov2024_x40a_18_97_inflow_131",
            dict(
                level_msl=18.97, previous_msl=18.50, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=4, stale=False, rain_24h_mm=180.0, rain_72h_mm=320.0,
                api_7d_mm=200.0, forecast_24h_mm=120.0, glofas_peak_ratio=3.5,
                dam_signal=0.75, lead_time_hours="6–12 ชม.",
            ),
            89.5, 5, True, "dam_release", "high",
        ),
        (
            "TV3-5_x77_rid8_39_70_critical",
            dict(
                level_msl=39.75, previous_msl=39.65, bank_m=40.3, watch_m=38.0, critical_m=39.7,
                situation_level=None, stale=False, is_flash_flood=True,
            ),
            38.0, 4, True, "riverine_overflow", "high",
        ),
        (
            "TV3-6_rain_only_no_push",
            dict(
                level_msl=12.0, previous_msl=12.0, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=None, stale=False, rain_1h_mm=40.0, forecast_24h_mm=33.0,
                is_urban_basin=True,
            ),
            18.3, 1, False, "monitoring", "high",
        ),
        (
            "TV3-7_kabang_0gauge_wet_soil_rain",
            dict(
                level_msl=None, previous_msl=None, bank_m=None, situation_level=None, stale=False,
                rain_1h_mm=48.0, api_7d_mm=140.0, forecast_24h_mm=66.0,
                is_flash_flood=True, has_water_gauge=False,
            ),
            32.6, 4, True, "flash_flood", "medium",
        ),
        (
            "TV3-8_banglang_spillway_early_warning",
            dict(
                level_msl=14.0, previous_msl=14.0, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=1, stale=False, rain_1h_mm=12.0, forecast_24h_mm=22.0,
                dam_signal=1.0, dam_spillway_active=True, lead_time_hours="6–12 ชม.",
            ),
            16.8, 3, True, "dam_release", "high",
        ),
        (
            "TV3-9_watch_rapid_rise_override",
            dict(
                level_msl=15.60, previous_msl=15.40, bank_m=16.5, watch_m=15.5, critical_m=16.5,
                situation_level=None, stale=False,
            ),
            25.7, 3, True, "riverine_overflow", "high",
        ),
        (
            "TV3-10_raman_sensor_gap_confidence",
            dict(
                level_msl=17.67, previous_msl=17.50, bank_m=16.5, watch_m=15.0, critical_m=16.5,
                situation_level=None, stale=False, rain_24h_mm=90.0, rain_sensor_gap=True,
                is_urban_basin=True,
            ),
            51.2, 5, True, "riverine_overflow", "medium",
        ),
    ],
)
def test_formula_v3_vectors(
    case_id, kwargs, expected_score, expected_level, expected_push, expected_mech, expected_conf
):
    res = P.compute_alert_v3(**kwargs)
    assert res["formula_version"] == 3
    assert res["score"] == expected_score, f"{case_id}: expected score {expected_score}, got {res['score']}"
    assert res["level"] == expected_level, f"{case_id}: expected level {expected_level}, got {res['level']}"
    assert res["should_push"] is expected_push
    assert res["flood_mechanism"] == expected_mech
    assert res["confidence"] == expected_conf


def test_banglang_high_inflow_surge_triggers_early_dam_signal():
    # Nov 2024: storage still 51%, release normal, but inflow surges to 130.98 MCM/day -> D = 0.75!
    dam = {"storage_percent": 51.0, "released_daily_mcm": 8.0, "spilled_mcm": 0.0, "inflow_daily_mcm": 130.98}
    d_sig, spilled, lead = P.compute_dam_signal(dam, "เมืองยะลา")
    assert d_sig == 0.75
    assert spilled is False
    assert lead == "6–12 ชม."


def test_station_registry_real_names_and_rid8_thresholds():
    reg = _registry()
    assert reg["X.273"]["display_name"] == "บ้านปายอยือนิ"
    assert reg["X.273"]["short_name_th"] == "บ้านปายอยือนิ"
    assert reg["X.40A"]["watch_m"] == 15.50
    assert reg["X.40A"]["critical_m"] == 16.50
    assert reg["X.77"]["watch_m"] == 38.00
    assert reg["X.77"]["critical_m"] == 39.70
    for code, item in reg.items():
        assert item.get("short_name_th") and not item["display_name"].endswith(" "), f"Bad name for {code}"
        assert item.get("name_en") and item.get("name_zh") and item.get("name_ms"), f"Missing i18n for {code}"


def test_curved_gis_boundaries_and_dem_elevation_assets():
    # Subdistricts must be high-res curved GADM polygons (not coarse 15-vertex polygons)
    subs = json.loads((P.REGISTRY_DIR / "yala_subdistricts.geojson").read_text(encoding="utf-8"))
    verts = [
        len(f["geometry"]["coordinates"][0])
        if f["geometry"]["type"] == "Polygon"
        else sum(len(p[0]) for p in f["geometry"]["coordinates"])
        for f in subs["features"]
    ]
    assert sum(verts) / len(verts) >= 35.0

    # DEM grid & topographic elevation zones exist and cover all 8 amphoes
    dem = json.loads((P.REGISTRY_DIR / "yala_dem_grid.json").read_text(encoding="utf-8"))
    assert dem["province_code"] == "95"
    assert dem["rows"] > 50 and dem["cols"] > 40
    non_null = sum(1 for row in dem["values"] for v in row if v is not None)
    assert non_null >= 1500

    ez = json.loads((P.REGISTRY_DIR / "yala_elevation_zones.geojson").read_text(encoding="utf-8"))
    assert len(ez["features"]) >= 100
    assert {f["properties"]["amphoe_th"] for f in ez["features"]} == set(_amphoes_registry().keys())

    vz = json.loads((P.REGISTRY_DIR / "yala_village_zones.geojson").read_text(encoding="utf-8"))
    assert len(vz["features"]) >= 400


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


# ── Option C: Tier C Community Reports Ingestion Tests ───────────────────────

def test_fetch_community_reports_returns_empty_when_unconfigured(monkeypatch):
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY", raising=False)
    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    assert P.fetch_community_reports_60m(fixed) == {}


def test_fetch_community_reports_rejects_non_https():
    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    with pytest.raises(P.ValidationError):
        P.fetch_community_reports_60m(
            fixed,
            supabase_url="http://insecure.supabase.co",
            service_key="secret",
        )


def test_fetch_community_reports_filters_trust_score_gte_3(monkeypatch):
    class _FakeResp:
        def raise_for_status(self):
            return None

        def json(self):
            return [
                {"amphoe_th": "เมืองยะลา", "trust_score": 4},
                {"amphoe_th": "เมืองยะลา", "trust_score": 3},
                {"amphoe_th": "เมืองยะลา", "trust_score": 1},  # unverified -> must be ignored
                {"amphoe_th": "กาบัง", "trust_score": 5},
                {"amphoe_th": "กรุงเทพมหานคร", "trust_score": 5},  # non-Yala -> must be ignored
            ]

    monkeypatch.setattr(P.requests, "get", lambda *a, **kw: _FakeResp())
    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    counts = P.fetch_community_reports_60m(
        fixed,
        supabase_url="https://demo.supabase.co",
        service_key="srv-key",
    )
    assert counts == {"เมืองยะลา": 2, "กาบัง": 1}


def test_normalize_and_amphoe_summaries_use_community_reports_never_sole_lv5():
    fixed = datetime(2026, 11, 24, 15, 0, tzinfo=P.ICT)
    rows = _rows_sample(1, at=fixed)
    rows[0]["station"]["tele_station_oldcode"] = "X.40A"
    rows[0]["waterlevel_msl"] = "11.00"
    rows[0]["waterlevel_msl_previous"] = "11.00"
    rows[0]["situation_level"] = 1

    st_without, _ = P.normalize(rows, _registry(), now=fixed)
    st_with, _ = P.normalize(
        rows,
        _registry(),
        now=fixed,
        community_reports_by_amphoe={"เมืองยะลา": 5},
    )
    assert st_with[0]["assessment"]["score"] > st_without[0]["assessment"]["score"]
    assert "community_reports" in st_with[0]["assessment"]["reason_codes"]
    # Guardrail: Tier C community reports alone MUST NEVER trigger Level 5 evacuation
    assert st_with[0]["assessment"]["level"] < 5

    # Also verify 0-gauge amphoe (อ.กาบัง) incorporates community_reports_by_amphoe
    _, amphoes_reg, _, _ = P.load_registry()
    kabang_only = {"กาบัง": amphoes_reg["กาบัง"]}
    s0 = P.build_amphoe_summaries(kabang_only, [], {}, {}, None, community_reports_by_amphoe={})
    s5 = P.build_amphoe_summaries(kabang_only, [], {}, {}, None, community_reports_by_amphoe={"กาบัง": 5})
    assert s5[0]["assessment"]["score"] > s0[0]["assessment"]["score"]
    assert s5[0]["assessment"]["level"] < 5


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
