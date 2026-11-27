#!/usr/bin/env python3
"""Yala Flood Watch — Interactive iOS Prototype & Live Multi-Source Simulation Server.

Run:
    backend/.venv/bin/python mobile/preview/serve.py
Open:
    http://127.0.0.1:8785/
"""
from __future__ import annotations

import copy
import json
import sys
from datetime import datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PREVIEW_DIR = Path(__file__).resolve().parent
REPO_ROOT = PREVIEW_DIR.parents[1]
BACKEND_DIR = REPO_ROOT / "backend"
OUT_DIR = BACKEND_DIR / "output"

sys.path.insert(0, str(BACKEND_DIR))
import pipeline as P  # noqa: E402


def _load_live_snapshot() -> dict:
    latest = OUT_DIR / "latest.json"
    if latest.exists():
        return json.loads(latest.read_text(encoding="utf-8"))
    rc, payload = P.run_pipeline(sync_mobile_asset=True)
    if rc == 0 and payload:
        return payload
    raise RuntimeError("No snapshot available and live pipeline failed")


def _load_manifest() -> dict:
    man = OUT_DIR / "manifest.json"
    if man.exists():
        return json.loads(man.read_text(encoding="utf-8"))
    return {}


def _build_scenario(scenario_id: str) -> dict:
    """Apply realistic hydrological replay scenarios using exact Python compute_alert_v5."""
    snap = copy.deepcopy(_load_live_snapshot())
    if scenario_id == "live":
        snap["simulation_mode"] = {
            "id": "live",
            "is_simulated": False,
            "title_th": "ข้อมูลจริงเรียลไทม์จาก 5 ฐานข้อมูล",
            "description_th": "แสดงข้อมูลสดจริงจาก ThaiWater (14 สถานีน้ำ + 87 สถานีฝน + เขื่อนบางลาง) และ Open-Meteo / GloFAS",
        }
        return snap

    _, amphoes_reg, _, _ = P.load_registry()
    dam = copy.deepcopy(snap.get("banglang_dam") or {})
    stations = snap.get("stations") or []
    amphoes_by_name = {a["amphoe"]: a for a in (snap.get("amphoes") or [])}

    if scenario_id == "banglang_spillway":
        dam["storage_percent"] = 92.4
        dam["storage_mcm"] = 1343.8
        dam["dam_level_msl"] = 113.6
        dam["inflow_daily_mcm"] = 34.2
        dam["released_daily_mcm"] = 28.5
        dam["spilled_mcm"] = 4.8
        dam["spillway_active"] = True
        dam["hourly_observed_at"] = datetime.now(P.ICT).strftime("%Y-%m-%d %H:00") + " (จำลอง)"

        for s in stations:
            amp = s["amphoe"]
            dam_sig, dam_spill, lead, dam_inflow = P.compute_dam_signal(dam, amp)
            if s["oldcode"] in ("BLGTD01", "BLGTD02", "PAT001"):
                s["level_msl"] = round((s["bank_m"] or 38.0) - 0.65, 2)
                s["previous_msl"] = round(s["level_msl"] - 0.34, 2)
                s["situation_level"] = 4
            elif s["oldcode"] in ("FOP045",):
                s["level_msl"] = round((s["level_msl"] or 5.80) + 0.34, 2)
                s["previous_msl"] = round(s["level_msl"] - 0.34, 2)
                s["situation_level"] = 4
            elif s["oldcode"] in ("X.40A", "BLGTD03", "PAT002"):
                s["level_msl"] = round((s["bank_m"] or 16.5) - 1.25, 2)
                s["previous_msl"] = round(s["level_msl"] - 0.18, 2)
                s["situation_level"] = 3
            s["stale"] = False
            s["remaining_to_bank_m"] = (
                round(s["bank_m"] - s["level_msl"], 2)
                if (s["bank_m"] is not None and s["level_msl"] is not None and not s.get("datum_unverified"))
                else None
            )
            s["rain_1h_mm"] = max(s.get("rain_1h_mm") or 0.0, 22.0)
            s["rain_24h_mm"] = max(s.get("rain_24h_mm") or 0.0, 78.0)
            s["forecast_24h_mm"] = max(s.get("forecast_24h_mm") or 0.0, 58.0)
            s["assessment"] = P.compute_alert_v5(
                level_msl=s["level_msl"],
                previous_msl=s["previous_msl"],
                bank_m=s["bank_m"],
                watch_m=s.get("watch_m"),
                critical_m=s.get("critical_m"),
                situation_level=s["situation_level"],
                stale=False,
                datum_unverified=bool(s.get("datum_unverified", False)),
                rain_1h_mm=s["rain_1h_mm"],
                rain_24h_mm=s["rain_24h_mm"],
                forecast_24h_mm=s["forecast_24h_mm"],
                dam_signal=dam_sig,
                dam_spillway_active=dam_spill,
                dam_inflow_daily_mcm=dam_inflow,
                is_flash_flood=s["is_flash_flood"],
                is_urban_basin=(amp in P.URBAN_BASIN_AMPHOES),
                lead_time_hours=lead,
            )

        snap["simulation_mode"] = {
            "id": scenario_id,
            "is_simulated": True,
            "title_th": "จำลอง: เขื่อนบางลางเปิด Spillway (เตือนล่วงหน้า 6–12 ชม.)",
            "description_th": (
                "จำลองระดับเขื่อนบางลาง 92.4% ระบายล้น Spillway 4.8 ล้าน ลบ.ม. → "
                "ระบบแจ้งเตือนล่วงหน้า อ.บันนังสตา (2–4 ชม.), อ.กรงปินัง (4–6 ชม.) และ "
                "อ.เมืองยะลา X.40A (6–12 ชม.) ก่อนน้ำล้นตลิ่ง"
            ),
        }

    elif scenario_id == "kabang_flash":
        for s in stations:
            amp = s["amphoe"]
            if amp in ("บันนังสตา", "ธารโต", "กรงปินัง", "เบตง"):
                s["rain_1h_mm"] = 54.0
                s["rain_24h_mm"] = 135.0
                s["forecast_24h_mm"] = 84.0
                if s["bank_m"]:
                    s["level_msl"] = round(s["bank_m"] - 0.90, 2)
                    s["previous_msl"] = round(s["level_msl"] - 0.36, 2)
                s["situation_level"] = max(s.get("situation_level") or 2, 3)
            s["stale"] = False
            s["remaining_to_bank_m"] = (
                round(s["bank_m"] - s["level_msl"], 2)
                if (s["bank_m"] is not None and s["level_msl"] is not None)
                else None
            )
            dam_sig, dam_spill, lead, dam_inflow = P.compute_dam_signal(dam, amp)
            s["assessment"] = P.compute_alert_v5(
                level_msl=s["level_msl"],
                previous_msl=s["previous_msl"],
                bank_m=s["bank_m"],
                watch_m=s.get("watch_m"),
                critical_m=s.get("critical_m"),
                situation_level=s["situation_level"],
                stale=False,
                datum_unverified=bool(s.get("datum_unverified", False)),
                rain_1h_mm=s["rain_1h_mm"],
                rain_24h_mm=s["rain_24h_mm"],
                api_7d_mm=130.0 if amp in ("บันนังสตา", "ธารโต", "กรงปินัง", "เบตง") else 40.0,
                forecast_24h_mm=s["forecast_24h_mm"],
                dam_signal=dam_sig,
                dam_spillway_active=dam_spill,
                dam_inflow_daily_mcm=dam_inflow,
                is_flash_flood=s["is_flash_flood"],
                is_urban_basin=(amp in P.URBAN_BASIN_AMPHOES),
                lead_time_hours=lead,
            )

        if "กาบัง" in amphoes_by_name:
            amphoes_by_name["กาบัง"]["rain"]["max_rain_1h_mm"] = 56.5
            amphoes_by_name["กาบัง"]["rain"]["max_rain_24h_mm"] = 138.0
            amphoes_by_name["กาบัง"]["weather_forecast"]["forecast_24h_mm"] = 82.0
            amphoes_by_name["กาบัง"]["weather_forecast"]["forecast_72h_mm"] = 165.0

        snap["simulation_mode"] = {
            "id": scenario_id,
            "is_simulated": True,
            "title_th": "จำลอง: ฝนหนักฉับพลันภูเขา อ.กาบัง–บันนังสตา–ธารโต",
            "description_th": (
                "จำลองฝนภูเขา >54 มม./ชม. + ระดับน้ำขึ้นเร็ว dH ≥ 0.35 ม. พร้อมทดสอบระบบแจ้งเตือน "
                "อ.กาบัง (0 สถานีวัดระดับน้ำ) จากสถานีฝนจริง 4 แห่ง + พยากรณ์ Open-Meteo"
            ),
        }

    elif scenario_id == "nov2025_crisis":
        dam["storage_percent"] = 96.8
        dam["storage_mcm"] = 1407.8
        dam["dam_level_msl"] = 114.9
        dam["inflow_daily_mcm"] = 48.0
        dam["released_daily_mcm"] = 36.0
        dam["spilled_mcm"] = 9.2
        dam["spillway_active"] = True
        dam["hourly_observed_at"] = datetime.now(P.ICT).strftime("%Y-%m-%d %H:00") + " (จำลองวิกฤต)"

        for s in stations:
            amp = s["amphoe"]
            dam_sig, dam_spill, lead, dam_inflow = P.compute_dam_signal(dam, amp)
            if s["bank_m"]:
                s["level_msl"] = round(s["bank_m"] + 0.45, 2)
                s["previous_msl"] = round(s["level_msl"] - 0.42, 2)
            s["situation_level"] = 5
            s["stale"] = False
            s["remaining_to_bank_m"] = (
                round(s["bank_m"] - s["level_msl"], 2)
                if (s["bank_m"] is not None and s["level_msl"] is not None and not s.get("datum_unverified"))
                else None
            )
            s["rain_1h_mm"] = 62.0
            s["rain_24h_mm"] = 188.0
            s["forecast_24h_mm"] = 118.0
            s["assessment"] = P.compute_alert_v5(
                level_msl=s["level_msl"],
                previous_msl=s["previous_msl"],
                bank_m=s["bank_m"],
                watch_m=s.get("watch_m"),
                critical_m=s.get("critical_m"),
                situation_level=5,
                stale=False,
                datum_unverified=bool(s.get("datum_unverified", False)),
                rain_1h_mm=62.0,
                rain_24h_mm=188.0,
                rain_72h_mm=334.0,
                api_7d_mm=160.0,
                forecast_6h_mm=38.0,
                forecast_24h_mm=118.0,
                dam_signal=dam_sig,
                dam_spillway_active=dam_spill,
                dam_inflow_daily_mcm=dam_inflow,
                is_flash_flood=s["is_flash_flood"],
                is_urban_basin=(amp in P.URBAN_BASIN_AMPHOES),
                lead_time_hours=lead,
            )

        if "กาบัง" in amphoes_by_name:
            amphoes_by_name["กาบัง"]["rain"]["max_rain_1h_mm"] = 64.0
            amphoes_by_name["กาบัง"]["rain"]["max_rain_24h_mm"] = 195.0
            amphoes_by_name["กาบัง"]["weather_forecast"]["forecast_24h_mm"] = 115.0

        snap["simulation_mode"] = {
            "id": scenario_id,
            "is_simulated": True,
            "title_th": "จำลองวิกฤต: น้ำท่วมใหญ่ จ.ยะลา (ระดับ 5 อพยพทันที)",
            "description_th": (
                "จำลองสถานการณ์เทียบเคียงเหตุการณ์น้ำท่วมใหญ่ยะลา พ.ย. 2568 "
                "(กระทบครบทั้ง 8 อำเภอ ระดับน้ำล้นตลิ่ง + เขื่อนบางลาง Spillway + ฝนตกหนักต่อเนื่อง)"
            ),
        }

    amphoe_rain = {a["amphoe"]: a["rain"] for a in amphoes_by_name.values()}
    wx_by_amp = {a["amphoe"]: a["weather_forecast"] for a in amphoes_by_name.values()}
    snap["banglang_dam"] = dam
    snap["amphoes"] = P.build_amphoe_summaries(amphoes_reg, stations, amphoe_rain, wx_by_amp, dam)
    return snap


class PreviewHandler(BaseHTTPRequestHandler):
    def _send_json(self, data: dict, status: int = 200) -> None:
        raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _send_html(self, path: Path) -> None:
        raw = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self) -> None:
        if self.path in ("/", "/index.html"):
            self._send_html(PREVIEW_DIR / "index.html")
            return
        if self.path == "/dashboard":
            self._send_html(REPO_ROOT / "tools" / "dashboard" / "index.html")
            return
        if self.path == "/api/snapshot":
            try:
                self._send_json(_build_scenario("live"))
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
            return
        if self.path == "/api/manifest":
            self._send_json(_load_manifest())
            return
        if self.path == "/api/geojson":
            geo_path = BACKEND_DIR / "registry" / "yala_amphoes.geojson"
            if geo_path.exists():
                self._send_json(json.loads(geo_path.read_text(encoding="utf-8")))
            else:
                self._send_json({"error": "yala_amphoes.geojson not found"}, status=404)
            return
        if self.path == "/api/subdistricts":
            sub_path = BACKEND_DIR / "registry" / "yala_subdistricts.geojson"
            if sub_path.exists():
                self._send_json(json.loads(sub_path.read_text(encoding="utf-8")))
            else:
                self._send_json({"error": "yala_subdistricts.geojson not found"}, status=404)
            return
        if self.path == "/api/villages":
            vil_path = BACKEND_DIR / "registry" / "yala_villages.json"
            if vil_path.exists():
                self._send_json(json.loads(vil_path.read_text(encoding="utf-8")))
            else:
                self._send_json({"error": "yala_villages.json not found"}, status=404)
            return
        if self.path.startswith("/api/scenario/"):
            sc_id = self.path.split("/api/scenario/", 1)[1].split("?")[0]
            if sc_id not in ("live", "banglang_spillway", "kabang_flash", "nov2025_crisis"):
                self._send_json({"error": f"Unknown scenario: {sc_id}"}, status=404)
                return
            try:
                self._send_json(_build_scenario(sc_id))
            except Exception as e:
                self._send_json({"error": str(e)}, status=500)
            return
        self.send_error(HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        if self.path == "/api/refresh":
            rc, payload = P.run_pipeline(sync_mobile_asset=True)
            if rc == 0 and payload:
                payload["simulation_mode"] = {
                    "id": "live",
                    "is_simulated": False,
                    "title_th": "ดึงข้อมูลสดสำเร็จจากทั้ง 5 ฐานข้อมูลจริง",
                    "description_th": f"อัปเดตล่าสุดเมื่อ {payload.get('generated_at')}",
                }
                self._send_json(payload)
            else:
                self._send_json({"error": "Pipeline fail-closed — คงข้อมูลล่าสุดที่ปลอดภัยไว้"}, status=502)
            return
        self.send_error(HTTPStatus.NOT_FOUND)


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8785
    server = ThreadingHTTPServer(("127.0.0.1", port), PreviewHandler)
    print(f"Yala Flood Watch iOS Interactive Simulator -> http://127.0.0.1:{port}/")
    print(f"Provincial Operations Dashboard           -> http://127.0.0.1:{port}/dashboard")
    server.serve_forever()


if __name__ == "__main__":
    main()
