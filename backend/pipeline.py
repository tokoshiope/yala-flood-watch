#!/usr/bin/env python3
"""Yala Flood Watch — Multi-Source Early Warning Pipeline (formula_version = 2)

Connects 5 live public zero-key hydrological & meteorological databases for Yala Province (95):
  1. ThaiWater Waterlevel   (14 telemetric water-level stations — Primary, Fail-Closed)
  2. ThaiWater Rain 24h     (87 real-time rain gauges across all 8 amphoes incl. Kabang)
  3. ThaiWater Analyst Dam  (Bang Lang Dam EGAT hourly + RID daily storage/inflow/release/spillway)
  4. Open-Meteo Weather     (72-hour hourly rainfall forecast for all 8 amphoes, CC BY 4.0)
  5. Open-Meteo GloFAS v4   (7-day river discharge forecast for Pattani & Sai Buri rivers, CC BY 4.0)

Fail-closed guarantee:
  - If Primary ThaiWater Waterlevel fails, returns empty/non-OK, has out-of-bbox coordinates,
    or ALL stations are stale (> MAX_STALE_MINUTES), exits with code 1 and NEVER overwrites
    existing latest.json / manifest.json.
  - Secondary sources degrade gracefully with explicit `degraded_sources` flags so citizens
    never lose live water-level alerts during upstream secondary API outages.
"""
from __future__ import annotations

import argparse
from decimal import Decimal, ROUND_HALF_UP
import hashlib
import json
import math
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import requests
import yaml

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent
REGISTRY_DIR = BASE_DIR / "registry"
OUT_DIR = BASE_DIR / "output"
MOBILE_ASSET_DIR = REPO_ROOT / "mobile" / "app" / "assets" / "snapshots"

PROVINCE_CODE = "95"
WATERLEVEL_URL = (
    f"https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code={PROVINCE_CODE}"
)
RAIN_URL = (
    f"https://api-v3.thaiwater.net/api/v1/thaiwater30/public/rain_24h?province_code={PROVINCE_CODE}"
)
DAM_URL = "https://api-v3.thaiwater.net/api/v1/thaiwater30/analyst/dam"
OPEN_METEO_WEATHER_URL = "https://api.open-meteo.com/v1/forecast"
OPEN_METEO_FLOOD_URL = "https://flood-api.open-meteo.com/v1/flood"

# Keep backward-compatible alias for older tests/scripts
API_URL = WATERLEVEL_URL

SCHEMA_VERSION = 2
FORMULA_VERSION = 2
HTTP_TIMEOUT = 15
HTTP_RETRIES = 2
HTTP_RETRY_BACKOFF = 0.9
# RID stations report hourly; HII/EGAT report every 10-30 min -> 60 min station freshness threshold
MAX_STALE_MINUTES = 60
RAIN_STALE_MINUTES = 90
YALA_BBOX = (5.5, 7.2, 100.5, 101.9)  # lat_min, lat_max, lon_min, lon_max
ICT = ZoneInfo("Asia/Bangkok")  # UTC+7
USER_AGENT = "yala-flood-watch-pipeline/2.0 (+civic-open-data)"

FLASH_FLOOD_AMPHOES = {"บันนังสตา", "กรงปินัง", "เบตง", "กาบัง", "ธารโต"}
BANGLANG_DOWNSTREAM_LEAD_TIME = {
    "บันนังสตา": "2–4 ชม.",
    "กรงปินัง": "4–6 ชม.",
    "เมืองยะลา": "6–12 ชม.",
}

LEVEL_META = {
    1: {"label_th": "ปกติ", "color": "#2E7D32", "action_th": "ติดตามสถานการณ์ได้ตามปกติ"},
    2: {"label_th": "เฝ้าระวัง", "color": "#F9A825", "action_th": "ติดตามข่าวใกล้ชิด เตรียมถุงยังชีพและชาร์จแบต"},
    3: {"label_th": "เตือนภัย", "color": "#EF6C00", "action_th": "ยกของขึ้นที่สูง เตรียมเส้นทางและแผนอพยพ"},
    4: {"label_th": "เตือนภัยสูง", "color": "#E53935", "action_th": "พร้อมอพยพทันที ติดตามประกาศ ปภ.ยะลา (073-203559)"},
    5: {"label_th": "อันตราย", "color": "#B71C1C", "action_th": "อพยพทันทีไปยังศูนย์พักพิงปลอดภัย หากติดค้างโทร 1784 / 1669"},
}

FLOOD_CHECKPOINTS = [
    {"id": "pattani_x40a", "name": "แม่น้ำปัตตานี (สะพานท่าสาป X.40A)", "amphoe": "เมืองยะลา", "lat": 6.54053, "lon": 101.24976},
    {"id": "saiburi_x273", "name": "แม่น้ำสายบุรี (บ้านปายอยือนิ X.273)", "amphoe": "รามัน", "lat": 6.47977, "lon": 101.44474},
]


class ValidationError(Exception):
    pass


def _ict(dt: datetime) -> datetime:
    """Interpret naive datetimes as Asia/Bangkok (UTC+7); convert aware datetimes to ICT."""
    if dt.tzinfo is None:
        return dt.replace(tzinfo=ICT)
    return dt.astimezone(ICT)


def _round_half_up(value: float, decimals: int = 1) -> float:
    """Deterministic half-up rounding with IEEE-754 epsilon compensation for 100% Python <-> Dart parity."""
    scale = 10 ** decimals
    return math.floor(value * scale + 0.5 + 1e-9) / scale


def _clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def _th(v: Any) -> str:
    if isinstance(v, dict):
        return str(v.get("th") or "").strip()
    return str(v or "").strip()


def _to_float(v: Any) -> float | None:
    if v is None or v == "":
        return None
    try:
        val = float(v)
        return val if math.isfinite(val) else None
    except (ValueError, TypeError):
        return None


def _to_int(v: Any) -> int | None:
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except (ValueError, TypeError):
        return None


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(max(0.0, min(1.0, a))))


def _http_get_json(url: str, params: dict | None = None, timeout: int = HTTP_TIMEOUT) -> Any:
    last_err: Exception | None = None
    for attempt in range(HTTP_RETRIES + 1):
        try:
            r = requests.get(
                url,
                params=params,
                headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
                timeout=timeout,
            )
            r.raise_for_status()
            return r.json()
        except Exception as e:
            last_err = e
            if attempt < HTTP_RETRIES:
                time.sleep(HTTP_RETRY_BACKOFF * (attempt + 1))
    raise ValidationError(f"HTTP fetch failed for {url}: {last_err}")


def load_registry() -> tuple[dict, dict, dict, dict]:
    with open(REGISTRY_DIR / "stations.yaml", encoding="utf-8") as f:
        stations = yaml.safe_load(f)["stations"]
    with open(REGISTRY_DIR / "amphoes.yaml", encoding="utf-8") as f:
        amphoes = yaml.safe_load(f)["amphoes"]
    with open(REGISTRY_DIR / "contacts.yaml", encoding="utf-8") as f:
        contacts = yaml.safe_load(f)
    with open(REGISTRY_DIR / "shelters.yaml", encoding="utf-8") as f:
        shelters = yaml.safe_load(f)
    return stations, amphoes, contacts, shelters


# ── Source 1: ThaiWater Waterlevel (Primary, Fail-Closed) ───────────────────

def fetch_raw(url: str | None = None) -> list[dict]:
    payload = _http_get_json(url or API_URL)
    if not isinstance(payload, dict):
        raise ValidationError("ThaiWater waterlevel response ไม่ใช่ JSON object (fail-closed)")
    if str(payload.get("result", "")).upper() != "OK":
        raise ValidationError(f"ThaiWater result={payload.get('result')!r} != OK (fail-closed)")
    rows = payload.get("data")
    if not isinstance(rows, list) or len(rows) == 0:
        raise ValidationError("ThaiWater waterlevel คืนข้อมูลว่าง (fail-closed)")
    return rows


# ── Source 2: ThaiWater Real-Time Rain (87 Gauges across all 8 amphoes) ─────

def fetch_rain_raw(url: str | None = None) -> list[dict]:
    payload = _http_get_json(url or RAIN_URL)
    if not isinstance(payload, dict) or str(payload.get("result", "")).upper() != "OK":
        raise ValidationError("ThaiWater rain_24h result != OK")
    rows = payload.get("data")
    if not isinstance(rows, list):
        raise ValidationError("ThaiWater rain_24h data ไม่ใช่ list")
    return rows


def normalize_rain(rows: list[dict], now: datetime) -> tuple[list[dict], dict[str, dict]]:
    """Normalize 87 Yala rain gauges and aggregate per amphoe."""
    now_ict = _ict(now)
    gauges: list[dict] = []
    by_amphoe: dict[str, list[dict]] = {}

    for r in rows:
        geo = r.get("geocode") or {}
        if str(geo.get("province_code", PROVINCE_CODE)) != PROVINCE_CODE:
            continue
        st = r.get("station") or {}
        lat = _to_float(st.get("tele_station_lat"))
        lon = _to_float(st.get("tele_station_long"))
        if lat is None or lon is None:
            continue
        if not (YALA_BBOX[0] <= lat <= YALA_BBOX[1] and YALA_BBOX[2] <= lon <= YALA_BBOX[3]):
            continue

        obs_str = r.get("rainfall_datetime")
        obs_at = None
        if isinstance(obs_str, str) and obs_str.strip():
            for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
                try:
                    obs_at = _ict(datetime.strptime(obs_str.strip(), fmt))
                    break
                except ValueError:
                    continue
        age_min = round((now_ict - obs_at).total_seconds() / 60.0, 1) if obs_at else None
        stale = (age_min is None) or (age_min > RAIN_STALE_MINUTES) or (age_min < -15.0)

        rain_1h = _to_float(r.get("rain_1h"))
        rain_24h = _to_float(r.get("rain_24h"))
        # Filter negative sensor anomalies
        if rain_1h is not None and rain_1h < 0:
            rain_1h = None
        if rain_24h is not None and rain_24h < 0:
            rain_24h = None

        amphoe = _th(geo.get("amphoe_name"))
        rec = {
            "id": r.get("id"),
            "oldcode": str(st.get("tele_station_oldcode") or "").strip(),
            "name": _th(st.get("tele_station_name")),
            "amphoe": amphoe,
            "tumbon": _th(geo.get("tumbon_name")),
            "lat": lat,
            "lon": lon,
            "rain_1h_mm": rain_1h,
            "rain_24h_mm": rain_24h,
            "observed_at": obs_str,
            "age_minutes": age_min,
            "stale": stale,
            "agency": _th((r.get("agency") or {}).get("agency_shortname")),
        }
        gauges.append(rec)
        if amphoe:
            by_amphoe.setdefault(amphoe, []).append(rec)

    amphoe_rain: dict[str, dict] = {}
    for amp, items in by_amphoe.items():
        fresh = [g for g in items if not g["stale"]]
        active = fresh if fresh else items
        r1_vals = [g["rain_1h_mm"] for g in active if g["rain_1h_mm"] is not None]
        r24_vals = [g["rain_24h_mm"] for g in active if g["rain_24h_mm"] is not None]
        amphoe_rain[amp] = {
            "gauge_count": len(items),
            "fresh_gauge_count": len(fresh),
            "max_rain_1h_mm": round(max(r1_vals), 2) if r1_vals else 0.0,
            "avg_rain_1h_mm": round(sum(r1_vals) / len(r1_vals), 2) if r1_vals else 0.0,
            "max_rain_24h_mm": round(max(r24_vals), 2) if r24_vals else 0.0,
            "avg_rain_24h_mm": round(sum(r24_vals) / len(r24_vals), 2) if r24_vals else 0.0,
            "stale": len(fresh) == 0,
            "latest_observed_at": max((g["observed_at"] for g in active if g["observed_at"]), default=None),
        }
    return gauges, amphoe_rain


# ── Source 3: ThaiWater Analyst Dam (Bang Lang Dam — EGAT Hourly + RID Daily)

def fetch_banglang_dam(url: str | None = None) -> dict:
    payload = _http_get_json(url or DAM_URL)
    if not isinstance(payload, dict) or str(payload.get("result", "")).upper() != "OK":
        raise ValidationError("ThaiWater analyst/dam result != OK")
    data = payload.get("data") or {}

    def _find_banglang(items: list[dict]) -> dict | None:
        for item in items:
            dam_info = item.get("dam") or {}
            name_th = _th(dam_info.get("dam_name"))
            if "บางลาง" in name_th:
                return item
        return None

    hourly = _find_banglang(data.get("dam_hourly") or [])
    daily = _find_banglang(data.get("dam_daily") or [])
    if not hourly and not daily:
        raise ValidationError("ไม่พบข้อมูลเขื่อนบางลางใน ThaiWater analyst/dam")

    daily_dam = (daily or {}).get("dam") or {}
    normal_storage = _to_float(daily_dam.get("normal_storage"))
    normal_storage = normal_storage if (normal_storage is not None and normal_storage > 0) else 1454.36
    max_storage = _to_float(daily_dam.get("max_storage"))
    max_storage = max_storage if (max_storage is not None and max_storage > 0) else 1589.83

    def _nonneg(val: float | None) -> float | None:
        return val if (val is not None and val >= 0) else None

    def _first_nonnull(*vals: float | None) -> float | None:
        for v in vals:
            if v is not None:
                return v
        return None

    storage_mcm = _first_nonnull(
        _nonneg(_to_float((hourly or {}).get("dam_storage"))),
        _nonneg(_to_float((daily or {}).get("dam_storage"))),
    )
    storage_pct = _nonneg(_to_float((daily or {}).get("dam_storage_percent")))
    if (storage_pct is None or storage_pct <= 0) and storage_mcm is not None and normal_storage > 0:
        storage_pct = round(100.0 * storage_mcm / normal_storage, 2)

    spilled_hourly = _nonneg(_to_float((hourly or {}).get("dam_spilled"))) or 0.0
    spilled_daily = _nonneg(_to_float((daily or {}).get("dam_spilled"))) or 0.0
    dam_spilled = max(spilled_hourly, spilled_daily)

    released_hourly = _nonneg(_to_float((hourly or {}).get("dam_released")))
    released_daily = _nonneg(_to_float((daily or {}).get("dam_released")))
    inflow_hourly = _nonneg(_to_float((hourly or {}).get("dam_inflow")))
    inflow_daily = _nonneg(_to_float((daily or {}).get("dam_inflow")))
    dam_level = _first_nonnull(
        _nonneg(_to_float((hourly or {}).get("dam_level"))),
        _nonneg(_to_float((daily or {}).get("dam_level"))),
    )

    return {
        "name_th": "เขื่อนบางลาง",
        "amphoe": "บันนังสตา",
        "lat": 6.15473,
        "lon": 101.273,
        "hourly_observed_at": (hourly or {}).get("dam_date"),
        "daily_observed_at": (daily or {}).get("dam_date"),
        "dam_level_msl": dam_level,
        "storage_mcm": storage_mcm,
        "normal_storage_mcm": normal_storage,
        "max_storage_mcm": max_storage,
        "storage_percent": storage_pct,
        "inflow_hourly_mcm": inflow_hourly,
        "inflow_daily_mcm": inflow_daily,
        "released_hourly_mcm": released_hourly,
        "released_daily_mcm": released_daily,
        "spilled_mcm": dam_spilled,
        "spillway_active": dam_spilled > 0,
        "agency": "กฟผ. (รายชั่วโมง) / กรมชลประทาน (รายวัน)",
        "downstream_travel_time": BANGLANG_DOWNSTREAM_LEAD_TIME,
    }


# ── Source 4: Open-Meteo Weather Forecast (All 8 Amphoes in 1 batch request) ─

def fetch_open_meteo_weather(amphoes_reg: dict, now: datetime | None = None) -> dict[str, dict]:
    names = list(amphoes_reg.keys())
    lats = ",".join(str(amphoes_reg[a]["lat"]) for a in names)
    lons = ",".join(str(amphoes_reg[a]["lon"]) for a in names)
    payload = _http_get_json(
        OPEN_METEO_WEATHER_URL,
        params={
            "latitude": lats,
            "longitude": lons,
            "hourly": "precipitation,rain,precipitation_probability",
            "daily": "precipitation_sum,precipitation_probability_max",
            "timezone": "Asia/Bangkok",
            "forecast_days": 3,
        },
    )
    items = payload if isinstance(payload, list) else [payload]
    now_ict = _ict(now or datetime.now(ICT))
    out: dict[str, dict] = {}
    for idx, amp in enumerate(names):
        if idx >= len(items):
            continue
        item = items[idx]
        hourly = item.get("hourly") or {}
        daily = item.get("daily") or {}
        precip = [float(x or 0.0) for x in (hourly.get("precipitation") or [])]
        probs = [int(x or 0) for x in (hourly.get("precipitation_probability") or [])]
        times = hourly.get("time") or []
        daily_sums = [float(x or 0.0) for x in (daily.get("precipitation_sum") or [])]
        daily_dates = daily.get("time") or []

        # Align from current ICT hour onward
        now_hour_prefix = now_ict.strftime("%Y-%m-%dT%H:00")
        start_i = 0
        for i, t in enumerate(times):
            if t >= now_hour_prefix:
                start_i = i
                break
        next_6 = precip[start_i:start_i + 6]
        next_24 = precip[start_i:start_i + 24]
        next_72 = precip[start_i:start_i + 72]
        probs_24 = probs[start_i:start_i + 24]

        out[amp] = {
            "source": "Open-Meteo (CC BY 4.0)",
            "forecast_6h_mm": round(sum(next_6), 2),
            "forecast_24h_mm": round(sum(next_24), 2),
            "forecast_72h_mm": round(sum(next_72), 2),
            "max_prob_24h_pct": max(probs_24) if probs_24 else 0,
            "hourly_next_24h": [
                {"time": times[start_i + k], "mm": round(next_24[k], 2), "prob": probs_24[k] if k < len(probs_24) else 0}
                for k in range(len(next_24))
            ],
            "daily_3d": [
                {"date": daily_dates[k], "mm": round(daily_sums[k], 2)}
                for k in range(min(len(daily_dates), len(daily_sums)))
            ],
        }
    return out


# ── Source 5: Open-Meteo Flood / GloFAS v4 (7-Day River Discharge) ──────────

def fetch_glofas_flood() -> list[dict]:
    lats = ",".join(str(c["lat"]) for c in FLOOD_CHECKPOINTS)
    lons = ",".join(str(c["lon"]) for c in FLOOD_CHECKPOINTS)
    payload = _http_get_json(
        OPEN_METEO_FLOOD_URL,
        params={
            "latitude": lats,
            "longitude": lons,
            "daily": "river_discharge,river_discharge_mean,river_discharge_max",
            "forecast_days": 7,
        },
    )
    items = payload if isinstance(payload, list) else [payload]
    out: list[dict] = []
    for idx, cp in enumerate(FLOOD_CHECKPOINTS):
        if idx >= len(items):
            continue
        daily = items[idx].get("daily") or {}
        dates = daily.get("time") or []
        dis = [_to_float(x) for x in (daily.get("river_discharge") or [])]
        mean = [_to_float(x) for x in (daily.get("river_discharge_mean") or [])]
        mx = [_to_float(x) for x in (daily.get("river_discharge_max") or [])]
        valid_dis = [x for x in dis if x is not None]
        valid_mean = [x for x in mean if x is not None and x > 0]
        peak_dis = max(valid_dis) if valid_dis else None
        avg_mean = (sum(valid_mean) / len(valid_mean)) if valid_mean else None
        ratio = round(peak_dis / avg_mean, 2) if (peak_dis is not None and avg_mean) else None
        out.append({
            **cp,
            "source": "Open-Meteo GloFAS v4 (CC BY 4.0)",
            "unit": "m³/s",
            "peak_discharge_7d": round(peak_dis, 2) if peak_dis is not None else None,
            "mean_discharge_baseline": round(avg_mean, 2) if avg_mean is not None else None,
            "peak_vs_mean_ratio": ratio,
            "daily_7d": [
                {
                    "date": dates[k],
                    "discharge": round(dis[k], 2) if k < len(dis) and dis[k] is not None else None,
                    "mean": round(mean[k], 2) if k < len(mean) and mean[k] is not None else None,
                    "max": round(mx[k], 2) if k < len(mx) and mx[k] is not None else None,
                }
                for k in range(len(dates))
            ],
        })
    return out


# ── Formula v2 Core Engine (100% Parity with Dart AlertEngine) ──────────────

def compute_dam_signal(dam: dict | None, amphoe: str) -> tuple[float, bool, str | None]:
    """Compute D (0..1), spillway_active, and downstream lead_time for an amphoe."""
    lead = BANGLANG_DOWNSTREAM_LEAD_TIME.get(amphoe)
    if not lead or not dam:
        return 0.0, False, lead
    spilled = _to_float(dam.get("spilled_mcm")) or 0.0
    storage_pct = _to_float(dam.get("storage_percent")) or 0.0
    released_daily = _to_float(dam.get("released_daily_mcm")) or 0.0

    if spilled > 0:
        return 1.0, True, lead
    if storage_pct >= 85.0 or released_daily >= 20.0:
        return 0.75, False, lead
    if storage_pct >= 75.0 or released_daily >= 12.0:
        return 0.45, False, lead
    if storage_pct >= 60.0:
        return round(_clamp((storage_pct - 60.0) / 50.0, 0.0, 0.35), 4), False, lead
    return 0.0, False, lead


def compute_alert_v2(
    *,
    level_msl: float | None,
    previous_msl: float | None,
    bank_m: float | None,
    situation_level: int | None,
    stale: bool,
    rain_1h_mm: float = 0.0,
    rain_24h_mm: float = 0.0,
    forecast_24h_mm: float = 0.0,
    dam_signal: float = 0.0,
    dam_spillway_active: bool = False,
    community_reports_60m: int = 0,
    is_flash_flood: bool = False,
    has_water_gauge: bool = True,
    h_normal_30d: float | None = None,
    lead_time_hours: str | None = None,
) -> dict:
    """Pure, deterministic Formula v2 evaluator matching docs/specs/spec-multisource-early-warning-v2.md."""
    flags: list[str] = []

    # 1. W (Water Level + dH/dt rate-of-rise bonus)
    dh = 0.0
    if level_msl is not None and previous_msl is not None and not stale:
        dh = round(level_msl - previous_msl, 4)

    w_val = 0.0
    if stale:
        flags.append("water_stale")
    elif bank_m is not None and bank_m > 0 and level_msl is not None:
        if h_normal_30d is not None:
            h_normal = h_normal_30d
        else:
            h_normal = bank_m - 2.0
            flags.append("h_normal_bootstrap")
        span = bank_m - h_normal
        w_base = _clamp((level_msl - h_normal) / span, 0.0, 1.0) if span > 0 else 0.0
        rise_bonus = 0.0
        if dh >= 0.30:
            rise_bonus = 0.15
            flags.append("rapid_rise")
        elif dh >= 0.15:
            rise_bonus = 0.08
            flags.append("rising_watch")
        w_val = _clamp(w_base + rise_bonus, 0.0, 1.0)
    elif situation_level is not None and 1 <= situation_level <= 4:
        w_val = _clamp(situation_level / 4.0, 0.0, 1.0)
        flags.append("w_from_situation_fallback")
    else:
        flags.append("no_water_signal")

    # 2. R (Observed real-time rain)
    r_val = _clamp(max(max(0.0, rain_1h_mm) / 60.0, max(0.0, rain_24h_mm) / 150.0), 0.0, 1.0)

    # 3. F (24h Forecast rain)
    f_val = _clamp(max(0.0, forecast_24h_mm) / 120.0, 0.0, 1.0)

    # 4. D (Bang Lang Dam downstream risk)
    d_val = _clamp(dam_signal, 0.0, 1.0)
    if dam_spillway_active:
        flags.append("dam_spillway_active")

    # 5. C (Verified community reports, trust >= 3)
    c_val = _clamp(max(0, community_reports_60m) / 5.0, 0.0, 1.0)

    # 6. Weighted Alert Score (0..100, half-up 1 decimal)
    raw = 0.45 * w_val + 0.22 * r_val + 0.13 * f_val + 0.10 * d_val + 0.10 * c_val
    score = _clamp(_round_half_up(100.0 * raw, 1), 0.0, 100.0)

    # 7. Base level from score (1..5)
    if score < 20.0:
        score_level = 1
    elif score < 40.0:
        score_level = 2
    elif score < 60.0:
        score_level = 3
    elif score < 80.0:
        score_level = 4
    else:
        score_level = 5

    # 8. Agency situation_level floor
    floor_level = int(_clamp(situation_level, 1, 4)) if situation_level is not None else 1
    if situation_level is not None and situation_level >= 3 and score_level <= 2:
        flags.append("situation_score_mismatch")
    level = max(score_level, floor_level)

    # 9. Flash flood override (+1 each for R>=0.7, C>=0.6, dH>=0.30; max +2, cap Level 5)
    flash_bonus = 0
    if is_flash_flood:
        if r_val >= 0.70:
            flash_bonus += 1
        if c_val >= 0.60:
            flash_bonus += 1
        if dh >= 0.30:
            flash_bonus += 1
        flash_bonus = min(flash_bonus, 2)
        if flash_bonus > 0:
            level = min(5, level + flash_bonus)
            flags.append(f"flash_override_+{flash_bonus}")

    # 10. Dam Spillway Early Warning Override (min Level 3 downstream)
    if dam_spillway_active and level < 3:
        level = 3
        flags.append("dam_spillway_floor_lv3")

    # 11. Push eligibility ("ฝนอย่างเดียวไม่ Push")
    has_primary_signal = (
        w_val > 0.0
        or (situation_level is not None and situation_level >= 2)
        or d_val >= 0.45
        or c_val >= 0.60
        or (is_flash_flood and not has_water_gauge and r_val >= 0.80 and f_val >= 0.50)
    )
    should_push = (level >= 2) and has_primary_signal

    meta = LEVEL_META[level]
    return {
        "formula_version": FORMULA_VERSION,
        "score": score,
        "score_level": score_level,
        "floor_level": floor_level,
        "flash_bonus": flash_bonus,
        "level": level,
        "label_th": meta["label_th"],
        "color": meta["color"],
        "action_th": meta["action_th"],
        "should_push": should_push,
        "has_primary_signal": has_primary_signal,
        "lead_time_hours": lead_time_hours if (dam_spillway_active or d_val >= 0.45) else None,
        "signals": {
            "W": round(w_val, 4),
            "R": round(r_val, 4),
            "F": round(f_val, 4),
            "D": round(d_val, 4),
            "C": round(c_val, 4),
            "dH_m": dh,
        },
        "flags": flags,
    }


# ── Water Station Normalization + Multi-Source Enrichment ───────────────────

def normalize(
    rows: list[dict],
    registry: dict,
    now: datetime | None = None,
    rain_gauges: list[dict] | None = None,
    amphoe_rain: dict[str, dict] | None = None,
    weather_by_amphoe: dict[str, dict] | None = None,
    banglang_dam: dict | None = None,
) -> tuple[list[dict], dict]:
    """Normalize ThaiWater waterlevel rows, apply registry fallback, and score with Formula v2."""
    now_ict = _ict(now or datetime.now(ICT))
    out: list[dict] = []
    seen_codes: set[str] = set()
    stats = {
        "stale": 0,
        "no_situation": 0,
        "no_bank": 0,
        "unknown_registry": 0,
        "bank_from_registry": 0,
        "storage_anomaly": 0,
        "duplicates_skipped": 0,
    }

    for r in rows:
        st = r.get("station") or {}
        geo = r.get("geocode") or {}
        if str(geo.get("province_code", PROVINCE_CODE)) != PROVINCE_CODE:
            continue

        oc = str(st.get("tele_station_oldcode") or "").strip()
        if oc and oc in seen_codes:
            stats["duplicates_skipped"] += 1
            continue
        if oc:
            seen_codes.add(oc)

        reg = registry.get(oc)
        if reg is None:
            stats["unknown_registry"] += 1
        reg_dict = reg or {}

        obs_str = r.get("waterlevel_datetime")
        obs_at = None
        if isinstance(obs_str, str) and obs_str.strip():
            for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
                try:
                    obs_at = _ict(datetime.strptime(obs_str.strip(), fmt))
                    break
                except ValueError:
                    continue
        age_min = round((now_ict - obs_at).total_seconds() / 60.0, 1) if obs_at else None
        stale = (age_min is None) or (age_min > MAX_STALE_MINUTES) or (age_min < -15.0)

        # Bank level with strict registry fallback (M-1 fix)
        api_bank = _to_float(st.get("left_bank")) or _to_float(st.get("right_bank")) or _to_float(st.get("min_bank"))
        bank = api_bank if (api_bank is not None and api_bank > 0) else None
        bank_source = "api"
        if bank is None:
            reg_bank = _to_float(reg_dict.get("left_bank_m"))
            if reg_bank is not None and reg_bank > 0:
                bank = reg_bank
                bank_source = "registry_fallback"
                stats["bank_from_registry"] += 1
            else:
                bank_source = "none"

        sit_raw = _to_int(r.get("situation_level"))
        situation = sit_raw if (sit_raw is not None and 1 <= sit_raw <= 4) else None

        storage = _to_float(r.get("storage_percent"))
        storage_anomaly = False
        if storage is not None and (storage < 0 or storage > 200):
            storage_anomaly = True
            storage = None
            stats["storage_anomaly"] += 1

        if stale:
            stats["stale"] += 1
        if situation is None:
            stats["no_situation"] += 1
        if bank is None:
            stats["no_bank"] += 1

        lvl = _to_float(r.get("waterlevel_msl"))
        prev_lvl = _to_float(r.get("waterlevel_msl_previous"))
        lat = _to_float(st.get("tele_station_lat"))
        lon = _to_float(st.get("tele_station_long"))
        amphoe = _th(geo.get("amphoe_name")) or str(reg_dict.get("amphoe") or "")

        # Match nearest fresh rain gauge (fallback to amphoe rain)
        r1_mm, r24_mm, nearest_rain_name = 0.0, 0.0, None
        if rain_gauges and lat is not None and lon is not None:
            fresh_gauges = [g for g in rain_gauges if not g["stale"]]
            pool = fresh_gauges if fresh_gauges else rain_gauges
            if pool:
                nearest = min(pool, key=lambda g: _haversine_km(lat, lon, g["lat"], g["lon"]))
                dist_km = _haversine_km(lat, lon, nearest["lat"], nearest["lon"])
                if dist_km <= 25.0:
                    r1_mm = nearest["rain_1h_mm"] or 0.0
                    r24_mm = nearest["rain_24h_mm"] or 0.0
                    nearest_rain_name = f"{nearest['name']} ({dist_km:.1f} กม.)"
        if amphoe_rain and amphoe in amphoe_rain:
            ar = amphoe_rain[amphoe]
            r1_mm = max(r1_mm, ar.get("max_rain_1h_mm", 0.0))
            r24_mm = max(r24_mm, ar.get("max_rain_24h_mm", 0.0))

        forecast_24h = ((weather_by_amphoe or {}).get(amphoe) or {}).get("forecast_24h_mm", 0.0)
        dam_sig, dam_spill, lead_time = compute_dam_signal(banglang_dam, amphoe)
        is_flash = (reg_dict.get("risk_zone") == "flash") or (amphoe in FLASH_FLOOD_AMPHOES)

        assessment = compute_alert_v2(
            level_msl=lvl,
            previous_msl=prev_lvl,
            bank_m=bank,
            situation_level=situation,
            stale=stale,
            rain_1h_mm=r1_mm,
            rain_24h_mm=r24_mm,
            forecast_24h_mm=forecast_24h,
            dam_signal=dam_sig,
            dam_spillway_active=dam_spill,
            community_reports_60m=0,
            is_flash_flood=is_flash,
            has_water_gauge=True,
            lead_time_hours=lead_time,
        )

        rec = {
            "id": r.get("id"),
            "oldcode": oc,
            "name": _th(st.get("tele_station_name")) or reg_dict.get("display_name") or oc,
            "river": _th(r.get("river_name")) or str(reg_dict.get("river") or ""),
            "amphoe": amphoe,
            "tumbon": _th(geo.get("tumbon_name")) or str(reg_dict.get("tumbon") or ""),
            "lat": lat,
            "lon": lon,
            "level_msl": lvl,
            "previous_msl": prev_lvl,
            "bank_m": bank,
            "bank_source": bank_source,
            "remaining_to_bank_m": round(bank - lvl, 3) if (bank is not None and lvl is not None) else None,
            "situation_level": situation,
            "storage_percent": storage,
            "storage_anomaly": storage_anomaly,
            "observed_at": obs_str,
            "age_minutes": age_min,
            "agency": _th((r.get("agency") or {}).get("agency_shortname")) or str(reg_dict.get("agency") or ""),
            "risk_zone": reg_dict.get("risk_zone", "unknown"),
            "is_flash_flood": is_flash,
            "registry_known": reg is not None,
            "stale": stale,
            "situation_missing": situation is None,
            "bank_missing": bank is None,
            "rain_1h_mm": round(r1_mm, 2),
            "rain_24h_mm": round(r24_mm, 2),
            "nearest_rain_gauge": nearest_rain_name,
            "forecast_24h_mm": round(forecast_24h, 2),
            "assessment": assessment,
        }
        out.append(rec)
    return out, stats


def build_amphoe_summaries(
    amphoes_reg: dict,
    stations: list[dict],
    amphoe_rain: dict[str, dict],
    weather_by_amphoe: dict[str, dict],
    banglang_dam: dict | None,
) -> list[dict]:
    """Produce unified Early Warning assessments for ALL 8 Yala amphoes (including Kabang)."""
    summaries: list[dict] = []
    for amp_name, meta in amphoes_reg.items():
        amp_stations = [s for s in stations if s["amphoe"] == amp_name]
        rain_info = amphoe_rain.get(amp_name) or {
            "gauge_count": 0,
            "fresh_gauge_count": 0,
            "max_rain_1h_mm": 0.0,
            "avg_rain_1h_mm": 0.0,
            "max_rain_24h_mm": 0.0,
            "avg_rain_24h_mm": 0.0,
            "stale": True,
            "latest_observed_at": None,
        }
        wx_info = weather_by_amphoe.get(amp_name) or {
            "forecast_6h_mm": 0.0,
            "forecast_24h_mm": 0.0,
            "forecast_72h_mm": 0.0,
            "max_prob_24h_pct": 0,
            "hourly_next_24h": [],
            "daily_3d": [],
        }
        dam_sig, dam_spill, lead_time = compute_dam_signal(banglang_dam, amp_name)

        if amp_stations:
            # Pick highest-risk station in amphoe as governing station
            worst = max(amp_stations, key=lambda s: (s["assessment"]["level"], s["assessment"]["score"]))
            assessment = worst["assessment"]
            gov_station = worst["oldcode"]
        else:
            # Amphoe with 0 water gauges (e.g., อ.กาบัง) — evaluated via real-time rain + Open-Meteo forecast!
            assessment = compute_alert_v2(
                level_msl=None,
                previous_msl=None,
                bank_m=None,
                situation_level=None,
                stale=False,
                rain_1h_mm=rain_info["max_rain_1h_mm"],
                rain_24h_mm=rain_info["max_rain_24h_mm"],
                forecast_24h_mm=wx_info["forecast_24h_mm"],
                dam_signal=dam_sig,
                dam_spillway_active=dam_spill,
                community_reports_60m=0,
                is_flash_flood=bool(meta.get("is_flash_flood", False)),
                has_water_gauge=False,
                lead_time_hours=lead_time,
            )
            gov_station = None

        summaries.append({
            "amphoe": amp_name,
            "name_en": meta.get("name_en"),
            "lat": meta.get("lat"),
            "lon": meta.get("lon"),
            "basin": meta.get("basin"),
            "risk_zone": meta.get("risk_zone"),
            "is_flash_flood": bool(meta.get("is_flash_flood", False)),
            "banglang_downstream": bool(meta.get("banglang_downstream", False)),
            "banglang_lead_time_hours": meta.get("banglang_lead_time_hours"),
            "risk_villages_10yr": meta.get("risk_villages_10yr"),
            "water_station_count": len(amp_stations),
            "governing_station": gov_station,
            "rain": rain_info,
            "weather_forecast": wx_info,
            "assessment": assessment,
            "note": meta.get("note"),
        })

    summaries.sort(key=lambda a: (-a["assessment"]["level"], -a["assessment"]["score"], a["amphoe"]))
    return summaries


def validate(stations: list[dict], stats: dict) -> None:
    """Fail-closed validation gates — any province-wide critical violation raises ValidationError."""
    if not stations:
        raise ValidationError("ไม่มีสถานีวัดระดับน้ำให้เขียน (fail-closed)")
    usable_count = 0
    for s in stations:
        if not s.get("name"):
            raise ValidationError(f"สถานี {s.get('oldcode')} ไม่มีชื่อ")
        lat, lon = s.get("lat"), s.get("lon")
        if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
            raise ValidationError(f"สถานี {s['name']} พิกัดไม่ถูกต้อง")
        if not (YALA_BBOX[0] <= lat <= YALA_BBOX[1] and YALA_BBOX[2] <= lon <= YALA_BBOX[3]):
            raise ValidationError(f"พิกัดสถานี {s['name']} นอกขอบเขตยะลา ({lat},{lon})")
        if s["level_msl"] is None and s["stale"]:
            s["unusable_sensor"] = True
        elif not s["stale"]:
            usable_count += 1
    if stats.get("stale", 0) == len(stations) or usable_count == 0:
        raise ValidationError(
            f"ทุกสถานีเก่าเกิน {MAX_STALE_MINUTES} นาทีหรือไม่มีค่าที่ใช้งานได้ — ต้นทางอาจล่ม (fail-closed)"
        )


def build_snapshot(
    stations: list[dict],
    contacts: dict,
    shelters: dict,
    *,
    amphoes: list[dict] | None = None,
    rain_gauges: list[dict] | None = None,
    banglang_dam: dict | None = None,
    glofas_flood: list[dict] | None = None,
    source_health: dict | None = None,
    degraded_sources: list[str] | None = None,
) -> dict:
    """Build deterministic snapshot body (excludes generated_at & content_hash)."""
    # Strip volatile age_minutes from deterministic body hash? Keep exact observed_at for determinism
    # Note: age_minutes depends on `now`, which is fixed in deterministic tests and reflects run time.
    return {
        "schema_version": SCHEMA_VERSION,
        "formula_version": FORMULA_VERSION,
        "province": {"code": PROVINCE_CODE, "name": "ยะลา", "name_en": "Yala"},
        "sources": {
            "thaiwater_waterlevel": WATERLEVEL_URL,
            "thaiwater_rain_24h": RAIN_URL,
            "thaiwater_dam": DAM_URL,
            "open_meteo_weather": OPEN_METEO_WEATHER_URL,
            "open_meteo_flood": OPEN_METEO_FLOOD_URL,
            "refresh_interval_hint_minutes": 15,
        },
        "source_health": source_health or {},
        "degraded_sources": sorted(degraded_sources or []),
        "banglang_dam": banglang_dam,
        "glofas_flood": glofas_flood or [],
        "amphoes": amphoes or [],
        "stations": sorted(stations, key=lambda s: (s["amphoe"], s["oldcode"] or s["name"])),
        "rain_gauges_summary": {
            "total": len(rain_gauges or []),
            "fresh": sum(1 for g in (rain_gauges or []) if not g.get("stale")),
            "top_rain_24h": sorted(
                [g for g in (rain_gauges or []) if (g.get("rain_24h_mm") or 0) > 0],
                key=lambda g: -(g.get("rain_24h_mm") or 0),
            )[:15],
        },
        "shelters": shelters.get("items", []),
        "shelters_status": shelters.get("status"),
        "shelters_notice_th": shelters.get("notice_th"),
        "contacts": contacts,
    }


def _strip_volatile_for_hash(obj: Any) -> Any:
    """Strip runtime-volatile fields (age_minutes, latency_ms) so identical telemetry hashes identically across runs."""
    if isinstance(obj, dict):
        return {
            k: _strip_volatile_for_hash(v)
            for k, v in obj.items()
            if k not in ("age_minutes", "latency_ms", "generated_at", "content_hash")
        }
    if isinstance(obj, list):
        return [_strip_volatile_for_hash(v) for v in obj]
    return obj


def content_hash(body: dict) -> str:
    stable = _strip_volatile_for_hash(body)
    canon = json.dumps(stable, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()


def _atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".{os.getpid()}.tmp")
    tmp.write_text(text, encoding="utf-8")
    os.replace(tmp, path)


def run_pipeline(sync_mobile_asset: bool = False, now: datetime | None = None) -> tuple[int, dict | None]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    now_ict = _ict(now or datetime.now(ICT))
    degraded: list[str] = []
    source_health: dict[str, dict] = {}

    try:
        registry_st, amphoes_reg, contacts, shelters = load_registry()

        # 1. Primary: ThaiWater Waterlevel (Fail-Closed)
        t0 = time.monotonic()
        water_rows = fetch_raw()
        source_health["thaiwater_waterlevel"] = {
            "status": "ok",
            "tier": "A",
            "count": len(water_rows),
            "latency_ms": round((time.monotonic() - t0) * 1000),
        }

        # 2. Secondary (High): ThaiWater Real-Time Rain (87 gauges)
        rain_gauges: list[dict] = []
        amphoe_rain: dict[str, dict] = {}
        try:
            t1 = time.monotonic()
            rain_rows = fetch_rain_raw()
            rain_gauges, amphoe_rain = normalize_rain(rain_rows, now_ict)
            source_health["thaiwater_rain_24h"] = {
                "status": "ok",
                "tier": "A",
                "count": len(rain_gauges),
                "amphoes_covered": len(amphoe_rain),
                "latency_ms": round((time.monotonic() - t1) * 1000),
            }
        except Exception as e:
            degraded.append("thaiwater_rain_24h")
            source_health["thaiwater_rain_24h"] = {"status": "degraded", "tier": "A", "error": str(e)}

        # 3. Secondary (High): ThaiWater Analyst Dam (Bang Lang Dam)
        banglang_dam: dict | None = None
        try:
            t2 = time.monotonic()
            banglang_dam = fetch_banglang_dam()
            source_health["thaiwater_dam"] = {
                "status": "ok",
                "tier": "A",
                "storage_percent": banglang_dam.get("storage_percent"),
                "spillway_active": banglang_dam.get("spillway_active"),
                "latency_ms": round((time.monotonic() - t2) * 1000),
            }
        except Exception as e:
            degraded.append("thaiwater_dam")
            source_health["thaiwater_dam"] = {"status": "degraded", "tier": "A", "error": str(e)}

        # 4. Secondary: Open-Meteo Weather Forecast (8 amphoes)
        weather_by_amphoe: dict[str, dict] = {}
        try:
            t3 = time.monotonic()
            weather_by_amphoe = fetch_open_meteo_weather(amphoes_reg, now=now_ict)
            source_health["open_meteo_weather"] = {
                "status": "ok",
                "tier": "B",
                "amphoes_covered": len(weather_by_amphoe),
                "latency_ms": round((time.monotonic() - t3) * 1000),
            }
        except Exception as e:
            degraded.append("open_meteo_weather")
            source_health["open_meteo_weather"] = {"status": "degraded", "tier": "B", "error": str(e)}

        # 5. Secondary: Open-Meteo GloFAS v4 Flood Forecast
        glofas_flood: list[dict] = []
        try:
            t4 = time.monotonic()
            glofas_flood = fetch_glofas_flood()
            source_health["open_meteo_flood"] = {
                "status": "ok",
                "tier": "B",
                "checkpoints": len(glofas_flood),
                "latency_ms": round((time.monotonic() - t4) * 1000),
            }
        except Exception as e:
            degraded.append("open_meteo_flood")
            source_health["open_meteo_flood"] = {"status": "degraded", "tier": "B", "error": str(e)}

        # Normalize, validate (Fail-Closed), and score all stations + 8 amphoes
        stations, stats = normalize(
            water_rows,
            registry_st,
            now=now_ict,
            rain_gauges=rain_gauges,
            amphoe_rain=amphoe_rain,
            weather_by_amphoe=weather_by_amphoe,
            banglang_dam=banglang_dam,
        )
        validate(stations, stats)

        amphoe_summaries = build_amphoe_summaries(
            amphoes_reg,
            stations,
            amphoe_rain,
            weather_by_amphoe,
            banglang_dam,
        )

        body = build_snapshot(
            stations,
            contacts,
            shelters,
            amphoes=amphoe_summaries,
            rain_gauges=rain_gauges,
            banglang_dam=banglang_dam,
            glofas_flood=glofas_flood,
            source_health=source_health,
            degraded_sources=degraded,
        )
        digest = content_hash(body)
        generated_at = now_ict.isoformat(timespec="seconds")
        payload = {**body, "generated_at": generated_at, "content_hash": digest}
        payload_text = json.dumps(payload, ensure_ascii=False, indent=2)

        ts = now_ict.strftime("%Y%m%d-%H%M%S")
        snap_path = OUT_DIR / f"snapshot-{ts}-{digest[:8]}.json"
        _atomic_write(snap_path, payload_text)
        _atomic_write(OUT_DIR / "latest.json", payload_text)

        manifest = {
            "schema_version": SCHEMA_VERSION,
            "formula_version": FORMULA_VERSION,
            "generated_at": generated_at,
            "count": len(stations),
            "amphoe_count": len(amphoe_summaries),
            "rain_gauge_count": len(rain_gauges),
            "content_hash": digest,
            "snapshot": snap_path.name,
            "degraded_sources": sorted(degraded),
            "source_health": source_health,
            "stats": stats,
        }
        manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2)
        _atomic_write(OUT_DIR / "manifest.json", manifest_text)

        if sync_mobile_asset:
            _atomic_write(MOBILE_ASSET_DIR / "latest.json", payload_text)
            _atomic_write(MOBILE_ASSET_DIR / "manifest.json", manifest_text)

        max_lv = max((a["assessment"]["level"] for a in amphoe_summaries), default=1)
        print(
            f"OK v{FORMULA_VERSION} stations={len(stations)} rain_gauges={len(rain_gauges)} "
            f"amphoes={len(amphoe_summaries)} max_level={max_lv} "
            f"degraded={len(degraded)} hash={digest[:12]}"
        )
        return 0, payload
    except ValidationError as e:
        print(f"PIPELINE_FAIL_CLOSED: {e}", file=sys.stderr)
        return 1, None
    except Exception as e:
        print(f"PIPELINE_FAIL_CLOSED: unexpected error: {e!r}", file=sys.stderr)
        return 1, None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Yala Flood Watch Multi-Source Pipeline")
    parser.add_argument(
        "--sync-mobile-asset",
        action="store_true",
        help="Also copy latest.json + manifest.json into mobile/app/assets/snapshots/ for offline-first bundle",
    )
    args = parser.parse_args(argv if argv is not None else [])
    rc, _ = run_pipeline(sync_mobile_asset=args.sync_mobile_asset)
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
