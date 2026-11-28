#!/usr/bin/env python3
"""Yala Flood Watch — Reproducible Historical Flood Replay Backtest (2567–2568).

Replays documented Yala flood milestones (RID / ThaiWater / Yala Province reports archived in
`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md` §2.1–2.2) plus dry-day false-alarm
controls through `pipeline.compute_alert_v5` and `evaluate_terrain_exposure_level`.

Note on provenance:
  - Input numbers come strictly from cited official daily/event reports (RID, HII/ThaiWater,
    Yala Province Agricultural/DDPM summaries). Where hourly pre-overflow series are not publicly
    published, milestone scenarios are explicitly marked `observed_milestone` vs `control_baseline`.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
import sys
from typing import Any

BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent
sys.path.insert(0, str(BASE_DIR))
import pipeline as P  # noqa: E402


@dataclass(frozen=True)
class BacktestScenario:
    id: str
    event_date: str
    category: str  # "flood_hit" | "early_warning" | "dry_control"
    provenance_tier: str  # "observed_milestone_with_reconstructed_aux" | "synthetic_flash_flood_stress_test" | "dry_control"
    amphoe: str
    station_code: str
    description_th: str
    source_citation: str
    inputs: dict[str, Any]
    expected_min_level: int
    expected_max_level: int
    expected_push: bool


SCENARIOS: tuple[BacktestScenario, ...] = (
    # ── Nov 2567 (2024) Major Flood — Pattani River & Bang Lang Dam ──
    BacktestScenario(
        id="BT-2567-01",
        event_date="2024-11-28",
        category="flood_hit",
        provenance_tier="observed_milestone_with_reconstructed_aux",
        amphoe="เมืองยะลา",
        station_code="X.40A",
        description_th="X.40A บ้านท่าสาปทำสถิติสูงสุด 18.97 ม.รทก. (เกินตลิ่ง 16.50 ม. กว่า +2.47 ม.) + น้ำเข้าเขื่อนบางลาง 130.98 ล้าน ลบ.ม./วัน",
        source_citation="Observed: X.40A=18.97m (RID WL_Max_lec.pdf), Bang Lang inflow=130.98 MCM/d (ThaiWater NOV2024); aux hourly inputs reconstructed",
        inputs=dict(
            level_msl=18.97,
            previous_msl=18.40,
            bank_m=16.50,
            watch_m=15.50,
            critical_m=16.50,
            situation_level=5,
            stale=False,
            rain_24h_mm=185.0,
            rain_72h_mm=340.0,
            api_7d_mm=220.0,
            dam_signal=0.80,
            dam_inflow_daily_mcm=130.98,
            is_urban_basin=True,
            lead_time_hours="6–12 ชม.",
        ),
        expected_min_level=5,
        expected_max_level=5,
        expected_push=True,
    ),
    BacktestScenario(
        id="BT-2567-02",
        event_date="2024-11-27",
        category="early_warning",
        provenance_tier="observed_milestone_with_reconstructed_aux",
        amphoe="ธารโต",
        station_code="X.77",
        description_th="ต้นน้ำเขื่อนบางลาง อ.ธารโต (X.77 บ้านหัวสะพาน, bank=40.30, critical=39.70) น้ำไหลเข้าเขื่อน 130.98 ล้าน ลบ.ม./วัน + ระดับเข้าช่วงเฝ้าระวังและขึ้นเร็ว",
        source_citation="Observed: Bang Lang inflow=130.98 MCM/d (ThaiWater NOV2024), X.77 Than To thresholds (สทภ.8 2568 / stations.yaml); aux stage/rain reconstructed",
        inputs=dict(
            level_msl=38.30,
            previous_msl=38.00,
            bank_m=40.30,
            watch_m=38.00,
            critical_m=39.70,
            situation_level=4,
            stale=False,
            rain_24h_mm=145.0,
            rain_72h_mm=240.0,
            api_7d_mm=165.0,
            forecast_24h_mm=90.0,
            dam_signal=0.75,
            dam_inflow_daily_mcm=130.98,
            is_flash_flood=True,
        ),
        expected_min_level=4,
        expected_max_level=4,
        expected_push=True,
    ),
    # ── Nov 2568 (2025) Urban Pluvial + Downstream Overflow (Dam only 57.1%!) ──
    BacktestScenario(
        id="BT-2568-01",
        event_date="2025-11-24",
        category="early_warning",
        provenance_tier="observed_milestone_with_reconstructed_aux",
        amphoe="เมืองยะลา",
        station_code="X.40A",
        description_th="ฝนสะสม 3 วัน (19–21 พ.ย. 68) อ.เมืองยะลา 333.8 มม. แม้อ่างบางลางมีน้ำเพียง 57.1% — ต้องเตือนภัยล่วงหน้าได้แม้แม่น้ำยังไม่แตะตลิ่ง",
        source_citation="Observed: Mueang Yala 3d rain=333.8mm, Bang Lang=57.1% (RID 24 Nov 2568); pre-overflow stage reconstructed",
        inputs=dict(
            level_msl=15.10,
            previous_msl=14.90,
            bank_m=16.50,
            watch_m=15.50,
            critical_m=16.50,
            situation_level=4,
            stale=False,
            rain_24h_mm=135.0,
            rain_72h_mm=333.8,
            api_7d_mm=210.0,
            forecast_24h_mm=85.0,
            dam_signal=0.20,
            is_urban_basin=True,
        ),
        expected_min_level=3,
        expected_max_level=4,
        expected_push=True,
    ),
    BacktestScenario(
        id="BT-2568-02",
        event_date="2025-11-27",
        category="flood_hit",
        provenance_tier="observed_milestone_with_reconstructed_aux",
        amphoe="เมืองยะลา",
        station_code="X.40A",
        description_th="X.40A บ้านท่าสาปสูงกว่าตลิ่ง +1.24 ม. (17.74 ม.รทก.) ขณะเขื่อนบางลาง 57.1% และ X.77 ต้นน้ำต่ำกว่าตลิ่ง 3.18 ม.",
        source_citation="Observed: X.40A=+1.24m above bank (17.74m), Bang Lang=57.1%, 3d rain=333.8mm (Yala Province 28 Nov 2568 p.17); aux hourly inputs reconstructed",
        inputs=dict(
            level_msl=17.74,
            previous_msl=17.40,
            bank_m=16.50,
            watch_m=15.50,
            critical_m=16.50,
            situation_level=None,  # RID gauge without situation_level
            stale=False,
            rain_24h_mm=95.0,
            rain_72h_mm=333.8,
            api_7d_mm=240.0,
            dam_signal=0.20,
            is_urban_basin=True,
        ),
        expected_min_level=5,
        expected_max_level=5,
        expected_push=True,
    ),
    BacktestScenario(
        id="BT-2568-03",
        event_date="2025-11-27",
        category="flood_hit",
        provenance_tier="observed_milestone_with_reconstructed_aux",
        amphoe="รามัน",
        station_code="X.273",
        description_th="แม่น้ำสายบุรี X.273 บ้านปายอยือนิสูงกว่าตลิ่ง +1.17 ม. (17.67 ม.รทก.) หลังฝนสะสม 3 วัน อ.รามัน 216.4 มม.",
        source_citation="Observed: Raman 3d rain=216.4mm (RID 24 Nov 2568) + X.273=+1.17m above bank (Yala Province 28 Nov 2568 p.17); aux hourly inputs reconstructed",
        inputs=dict(
            level_msl=17.67,
            previous_msl=17.35,
            bank_m=16.50,
            watch_m=15.00,
            critical_m=16.50,
            situation_level=None,
            stale=False,
            rain_24h_mm=88.0,
            rain_72h_mm=216.4,
            api_7d_mm=180.0,
            is_urban_basin=True,
        ),
        expected_min_level=5,
        expected_max_level=5,
        expected_push=True,
    ),
    BacktestScenario(
        id="BT-SYN-01",
        event_date="synthetic",
        category="early_warning",
        provenance_tier="synthetic_flash_flood_stress_test",
        amphoe="กาบัง",
        station_code="NO_GAUGE",
        description_th="[Synthetic Stress Test] อ.กาบัง (ไม่มีสถานีวัดระดับน้ำ) ทดสอบฝนหนักฉับพลันต้นน้ำ (R1=62 มม., R24=155 มม.) + พยากรณ์ฝนตกต่อ — Flash Flood Override",
        source_citation="Synthetic stress test (NOT RID 24 Nov 2568 Kabang 30.4 mm reading) validating no-gauge Flash Flood Override per DEC-011/DEC-022",
        inputs=dict(
            level_msl=None,
            previous_msl=None,
            bank_m=None,
            situation_level=None,
            stale=False,
            has_water_gauge=False,
            rain_1h_mm=62.0,
            rain_24h_mm=155.0,
            rain_72h_mm=210.0,
            api_7d_mm=140.0,
            forecast_24h_mm=95.0,
            is_flash_flood=True,
        ),
        expected_min_level=3,
        expected_max_level=4,
        expected_push=True,
    ),
    # ── Dry-Day & Sensor-Anomaly False-Alarm Controls (FAR = 0%) ──
    BacktestScenario(
        id="BT-CTRL-01",
        event_date="2026-11-27",
        category="dry_control",
        provenance_tier="dry_control",
        amphoe="เมืองยะลา",
        station_code="PAT002",
        description_th="วันปกติ PAT002 หน้าเขื่อนทดน้ำปัตตานีรักษาระดับน้ำปกติ 12.88 ม.รทก. (ThaiWater sit=4) — ต้องไม่แจ้งเตือนหลอก",
        source_citation="Live dry-season calibration (LL-003: PAT002 watch_m=13.30, critical_m=13.85)",
        inputs=dict(
            level_msl=12.88,
            previous_msl=12.88,
            bank_m=13.85,
            watch_m=13.30,
            critical_m=13.85,
            situation_level=4,
            stale=False,
            rain_24h_mm=8.0,
            is_urban_basin=True,
        ),
        expected_min_level=1,
        expected_max_level=1,
        expected_push=False,
    ),
    BacktestScenario(
        id="BT-CTRL-02",
        event_date="2026-11-27",
        category="dry_control",
        provenance_tier="dry_control",
        amphoe="กรงปินัง",
        station_code="FOP045",
        description_th="วันปกติ FOP045 สะพานกรงปินัง (datum_unverified=True, level=5.85 คงที่) — ต้องอยู่ระดับ 1 ปกติ ไม่ส่ง Push",
        source_citation="Live snapshot 2026-11-27 (LL-004 datum_unverified guard)",
        inputs=dict(
            level_msl=5.85,
            previous_msl=5.85,
            bank_m=25.128,
            watch_m=23.20,
            critical_m=25.128,
            situation_level=1,
            stale=False,
            datum_unverified=True,
            is_flash_flood=True,
        ),
        expected_min_level=1,
        expected_max_level=1,
        expected_push=False,
    ),
    BacktestScenario(
        id="BT-CTRL-03",
        event_date="2026-11-27",
        category="dry_control",
        provenance_tier="dry_control",
        amphoe="เมืองยะลา",
        station_code="X.40A",
        description_th="วันฝนโปรยปราย (R24=28 มม., H=12.50 ม., sit=3 ปกติ) — ต้องเงียบ 100% (FAR = 0%)",
        source_citation="Dry-day baseline control (LL-002 ThaiWater situation_level 1–5 scale calibration)",
        inputs=dict(
            level_msl=12.50,
            previous_msl=12.48,
            bank_m=16.50,
            watch_m=15.50,
            critical_m=16.50,
            situation_level=3,
            stale=False,
            rain_24h_mm=28.0,
            forecast_24h_mm=20.0,
            is_urban_basin=True,
        ),
        expected_min_level=1,
        expected_max_level=1,
        expected_push=False,
    ),
)


def run_backtest() -> dict[str, Any]:
    rows = []
    hits = 0
    misses = 0
    false_alarms = 0
    true_negatives = 0
    all_passed = True

    for sc in SCENARIOS:
        res = P.compute_alert_v5(**sc.inputs)
        lv = int(res["level"])
        pushed = bool(res["should_push"])
        passed = (
            sc.expected_min_level <= lv <= sc.expected_max_level
            and pushed == sc.expected_push
        )
        if not passed:
            all_passed = False

        if sc.category in ("flood_hit", "early_warning"):
            if lv >= sc.expected_min_level and pushed:
                hits += 1
            else:
                misses += 1
        else:
            if pushed or lv > 1:
                false_alarms += 1
            else:
                true_negatives += 1

        rows.append(
            {
                "scenario": sc,
                "level": lv,
                "score": res["score"],
                "basis": res["alert_basis"],
                "should_push": pushed,
                "label_th": res["label_th"],
                "passed": passed,
            }
        )

    pod = hits / (hits + misses) if (hits + misses) else 1.0
    far = false_alarms / (hits + false_alarms) if (hits + false_alarms) else 0.0
    csi = hits / (hits + misses + false_alarms) if (hits + misses + false_alarms) else 1.0

    return {
        "formula_version": P.FORMULA_VERSION,
        "generated_at": datetime.now(P.ICT).isoformat(timespec="seconds"),
        "all_passed": all_passed,
        "total": len(SCENARIOS),
        "hits": hits,
        "misses": misses,
        "false_alarms": false_alarms,
        "true_negatives": true_negatives,
        "pod": round(pod, 4),
        "far": round(far, 4),
        "csi": round(csi, 4),
        "rows": rows,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        f"# Yala Flood Watch — Historical Flood Backtest Report (2567–2568 · `formula_version = {report['formula_version']}`)",
        "",
        f"> **Generated:** {report['generated_at']} · **Verdict:** `{'PASS' if report['all_passed'] else 'FAIL'}`",
        "> **Scope:** Reproducible scenario replay combining observed Nov 2567 & Nov 2568 Yala flood milestone peaks (`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md` §2.1–2.2) with explicitly tagged reconstructed auxiliary hourly inputs, a synthetic no-gauge flash-flood stress test (`BT-SYN-01`), and dry-day false-alarm controls.",
        "",
        "## Summary Metrics",
        "",
        "| Metric | Value | Target |",
        "|---|---:|---:|",
        f"| Scenarios Evaluated | `{report['total']}` | All pass |",
        f"| Probability of Detection (POD) | `{report['pod'] * 100:.1f}%` ({report['hits']}/{report['hits'] + report['misses']}) | `100.0%` |",
        f"| False Alarm Ratio (FAR) | `{report['far'] * 100:.1f}%` ({report['false_alarms']} false alarms) | `0.0%` |",
        f"| Critical Success Index (CSI) | `{report['csi'] * 100:.1f}%` | `100.0%` |",
        f"| Dry-Day Controls Passed | `{report['true_negatives']}/{report['true_negatives'] + report['false_alarms']}` | `100.0%` |",
        "",
        "## Scenario-by-Scenario Replay Results",
        "",
        "| ID | Date | Amphoe / Station | Provenance Tier | Output Level | Basis | Push | Expected | Result |",
        "|---|---|---|---|---:|---|---:|---|---|",
    ]
    for r in report["rows"]:
        sc: BacktestScenario = r["scenario"]
        exp = (
            f"Lv {sc.expected_min_level}"
            if sc.expected_min_level == sc.expected_max_level
            else f"Lv {sc.expected_min_level}–{sc.expected_max_level}"
        )
        lines.append(
            f"| `{sc.id}` | {sc.event_date} | {sc.amphoe} (`{sc.station_code}`) | `{sc.provenance_tier}` "
            f"| **Lv {r['level']} ({r['label_th']})** | `{r['basis']}` | `{'Yes' if r['should_push'] else 'No'}` "
            f"| {exp} | `{'PASS' if r['passed'] else 'FAIL'}` |"
        )
    lines.extend([
        "",
        "## Provenance & Limitations",
        "- **`observed_milestone_with_reconstructed_aux`:** Peak stage (`X.40A=18.97m`, `X.40A=+1.24m`, `X.273=+1.17m`), 3-day rainfall (`333.8mm`, `216.4mm`), and Bang Lang Dam inflow (`130.98 MCM/d`) / storage (`57.1%`) come strictly from RID, HII/ThaiWater, and Yala Province public reports. Auxiliary hourly fields (`previous_msl`, `rain_24h_mm`, `api_7d_mm`, `forecast_24h_mm`) are reconstructed for milestone testing because raw 10-minute historical time series are not publicly published.",
        "- **`synthetic_flash_flood_stress_test` (`BT-SYN-01`):** Explicit synthetic stress test for no-gauge Amphoe Kabang (distinct from RID's 24 Nov 2568 30.4 mm reading) verifying the Flash Flood Override path.",
        "- Full hourly sub-event calibration awaits raw 10-minute historical series from RID/EGAT/HII (`docs/launch/ddpm-yala-verification-letter.md`).",
    ])
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Replay Nov 2567 & Nov 2568 Yala flood milestones through formula v5")
    parser.add_argument(
        "--write-report",
        default="",
        help="Optional markdown output path (e.g. docs/qa/backtest-yala-2567-2568.md)",
    )
    args = parser.parse_args(argv)
    report = run_backtest()
    if args.write_report:
        out = Path(args.write_report)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(render_markdown(report), encoding="utf-8")
    print(
        f"BACKTEST_{'PASS' if report['all_passed'] else 'FAIL'} "
        f"v{report['formula_version']} total={report['total']} "
        f"POD={report['pod']:.2f} FAR={report['far']:.2f} CSI={report['csi']:.2f}"
    )
    return 0 if report["all_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
