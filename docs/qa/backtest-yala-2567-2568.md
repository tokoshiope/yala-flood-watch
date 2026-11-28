# Yala Flood Watch — Historical Flood Backtest Report (2567–2568 · `formula_version = 5`)

> **Generated:** 2026-11-28T00:02:03+07:00 · **Verdict:** `PASS`
> **Scope:** Reproducible scenario replay combining observed Nov 2567 & Nov 2568 Yala flood milestone peaks (`docs/วิจัยระบบเตือนภัยน้ำท่วมยะลา-กรอบข้อมูลและเกณฑ์คำนวณ.md` §2.1–2.2) with explicitly tagged reconstructed auxiliary hourly inputs, a synthetic no-gauge flash-flood stress test (`BT-SYN-01`), and dry-day false-alarm controls.

## Summary Metrics

| Metric | Value | Target |
|---|---:|---:|
| Scenarios Evaluated | `9` | All pass |
| Probability of Detection (POD) | `100.0%` (6/6) | `100.0%` |
| False Alarm Ratio (FAR) | `0.0%` (0 false alarms) | `0.0%` |
| Critical Success Index (CSI) | `100.0%` | `100.0%` |
| Dry-Day Controls Passed | `3/3` | `100.0%` |

## Scenario-by-Scenario Replay Results

| ID | Date | Amphoe / Station | Provenance Tier | Output Level | Basis | Push | Expected | Result |
|---|---|---|---|---:|---|---:|---|---|
| `BT-2567-01` | 2024-11-28 | เมืองยะลา (`X.40A`) | `observed_milestone_with_reconstructed_aux` | **Lv 5 (อันตราย)** | `water_stage` | `Yes` | Lv 5 | `PASS` |
| `BT-2567-02` | 2024-11-27 | ธารโต (`X.77`) | `observed_milestone_with_reconstructed_aux` | **Lv 4 (เตือนภัยสูง)** | `water_stage` | `Yes` | Lv 4 | `PASS` |
| `BT-2568-01` | 2025-11-24 | เมืองยะลา (`X.40A`) | `observed_milestone_with_reconstructed_aux` | **Lv 3 (เตือนภัย)** | `rain_dam_early_warning` | `Yes` | Lv 3–4 | `PASS` |
| `BT-2568-02` | 2025-11-27 | เมืองยะลา (`X.40A`) | `observed_milestone_with_reconstructed_aux` | **Lv 5 (อันตราย)** | `water_stage` | `Yes` | Lv 5 | `PASS` |
| `BT-2568-03` | 2025-11-27 | รามัน (`X.273`) | `observed_milestone_with_reconstructed_aux` | **Lv 5 (อันตราย)** | `water_stage` | `Yes` | Lv 5 | `PASS` |
| `BT-SYN-01` | synthetic | กาบัง (`NO_GAUGE`) | `synthetic_flash_flood_stress_test` | **Lv 3 (เตือนภัย)** | `rain_dam_early_warning` | `Yes` | Lv 3–4 | `PASS` |
| `BT-CTRL-01` | 2026-11-27 | เมืองยะลา (`PAT002`) | `dry_control` | **Lv 1 (ปกติ)** | `monitoring` | `No` | Lv 1 | `PASS` |
| `BT-CTRL-02` | 2026-11-27 | กรงปินัง (`FOP045`) | `dry_control` | **Lv 1 (ปกติ)** | `monitoring` | `No` | Lv 1 | `PASS` |
| `BT-CTRL-03` | 2026-11-27 | เมืองยะลา (`X.40A`) | `dry_control` | **Lv 1 (ปกติ)** | `monitoring` | `No` | Lv 1 | `PASS` |

## Provenance & Limitations
- **`observed_milestone_with_reconstructed_aux`:** Peak stage (`X.40A=18.97m`, `X.40A=+1.24m`, `X.273=+1.17m`), 3-day rainfall (`333.8mm`, `216.4mm`), and Bang Lang Dam inflow (`130.98 MCM/d`) / storage (`57.1%`) come strictly from RID, HII/ThaiWater, and Yala Province public reports. Auxiliary hourly fields (`previous_msl`, `rain_24h_mm`, `api_7d_mm`, `forecast_24h_mm`) are reconstructed for milestone testing because raw 10-minute historical time series are not publicly published.
- **`synthetic_flash_flood_stress_test` (`BT-SYN-01`):** Explicit synthetic stress test for no-gauge Amphoe Kabang (distinct from RID's 24 Nov 2568 30.4 mm reading) verifying the Flash Flood Override path.
- Full hourly sub-event calibration awaits raw 10-minute historical series from RID/EGAT/HII (`docs/launch/ddpm-yala-verification-letter.md`).
