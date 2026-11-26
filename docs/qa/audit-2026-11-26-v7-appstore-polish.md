# Independent QA / Hydrology & Security Audit Report v7 — `v1.0.1+8` (`DEC-020`)

> **Date:** 2026-11-26  
> **Auditor:** Independent Read-Only Subagent (`d744d4c3-8bcb-406b-aa4a-fdc32326be37`, separate context per `AGENTS.md §4`)  
> **Scope:** App Icon Option 2 (15 iOS PNGs no-alpha), Zero SOS Messaging & Zero UGC Emergency Tab, iOS Weather-Style Vertical Rain Bar Chart, Hero Remaining-to-Bank + 7-Day Interactive Water-Level Chart + 10-Min Pipeline Cron, Village/Tambon Watch Areas, Shelter Call Button with Phone Number, Apple Guideline 2.1 & PDPA Privacy Consistency  
> **Initial Audit Verdict:** `HOLD` (0 BLOCKER · 2 HIGH · 3 MEDIUM · 2 code LOW)  
> **Re-Audit Final Verdict:** **`PASS`** ✅ *(0 BLOCKER · 0 HIGH · 0 MEDIUM · 0 open code defects — Approved for Gate 3 Release `1.0.1+8`)*

---

## 1. Automated Verification Evidence

| Verification Gate | Result |
|---|---|
| `backend/.venv/bin/pytest -q backend/tests` | **PASS** — `51/51 passed` (0.35s) |
| Live Pipeline `backend/pipeline.py --sync-mobile-asset` | **PASS** — `v3 stations=14 rain_gauges=88 amphoes=8 degraded=0`, 14/14 stations 7-day `history_7d` (129–168 pts), 8/8 amphoes 6 `watch_areas` |
| `publish_supabase.py --dry-run` & `notify_fcm.py --dry-run` | **PASS** — `DRY_RUN_OK hash=ac9df4214892`, `FCM_DRY_RUN_OK` |
| `flutter analyze` | **PASS** — `0 issues` |
| `flutter test` | **PASS** — `84/84 passed` (incl. 375pt + 1.35× Large Text Mode regression test) |
| `plutil -lint Info.plist PrivacyInfo.xcprivacy` | **PASS** — both `OK` |
| iOS AppIcon binary audit (`Contents.json` 19 slots / 15 PNGs) | **PASS** — 15/15 exact dimensions, RGB `color_type=2`, **0 alpha channels** (+ `design/app-icon-1024.png` + `web/icon-512.png`) |
| Village / Subdistrict 4-language dataset audit | **PASS** — 449 villages & 58 subdistricts across all 8 amphoes (incl. อ.กาบัง: 19), 0 missing English names |

---

## 2. Findings Tracked & Verified Resolved in Re-Audit

| ID | Severity | Finding | Resolution Verified |
|---|---|---|---|
| **HIGH-1** | HIGH | Horizontal `RenderFlex` overflow & vertical clipping in `_RainForecastCard` readout, amphoe `ChoiceChip` strip (`38px`), Y-axis (`36px`), and `_AlertTile` footer on 375pt iPhone at 1.25×+ Large Text Mode | **RESOLVED** — Converted readouts & `_AlertTile` footer to `Wrap`, raised chip strip to `50px`, widened Y-axis to `44px` with `FittedBox` + clamped chart `textScaler` `[0.9, 1.15]`, verified via 375pt + 1.35× widget test (`0` exceptions) |
| **HIGH-2** | HIGH | `_ChartCard` inspected readout, `24h/3d/7d + pts` row, and `34px` hero remaining-to-bank text could overflow on 375pt iPhone + Large Text Mode | **RESOLVED** — Wrapped hero number in `FittedBox(fit: BoxFit.scaleDown)`, converted range chips to `Wrap`, stacked inspected readout in `Column` and default min/max in `Wrap`, verified via 375pt + 1.35× widget test |
| **MEDIUM-1** | MEDIUM | Light-rain text `#38BDF8` on `#F0F7FF` had ~2.0:1 contrast in Light Mode | **RESOLVED** — Added `_rainTextColor()` using `#0369A1` (~5.7:1 WCAG AA) on Light Mode while keeping bright sky blue bar fills |
| **MEDIUM-2** | MEDIUM | `PrivacyInfo.xcprivacy` declared `PreciseLocation` while App Store Connect recommended "No — Data Not Collected" (mismatch risk) | **RESOLVED** — Aligned `PrivacyInfo.xcprivacy` (`NSPrivacyCollectedDataTypes = []`, `plutil -lint OK`) with `docs/launch/app-store-metadata.md` (**No — Data Not Collected**) and `web/privacy.html` (on-device GPS never transmitted off-device) |
| **MEDIUM-3** | MEDIUM | Stale `zh`/`ms` labels on `request_help_btn` still mentioned "SOS" | **RESOLVED** — Updated `zh` (`查看紧急联络渠道 (电话 / LINE / Facebook)`) & `ms` (`Saluran Kecemasan (Telefon / LINE / Facebook)`) in `app_strings.dart` |
| **LOW-1** | LOW | Dashed bank/watch line scale check used only `minV`, hiding bank line if a flash flood rose >10m | **RESOLVED** — Checks `math.min((threshold - minV).abs(), (threshold - maxV).abs()) <= 10.0` + added `chartW <= 0 || chartH <= 0` guard |
| **LOW-2** | LOW | Agency cadence lookup matched `'พพภ'` without period | **RESOLVED** — Matches both `'พพภ'` and `'พพภ.'` in `station.dart` & `backend/pipeline.py` |

---

## 3. Gate 3 Release Readiness

- **Verdict:** **`PASS`** — Ready for Founder **Gate 3 approval** to push to GitHub, build Release IPA (`1.0.1 Build 8` targeting `lib/main.dart`), and upload to Apple TestFlight so the Founder can record the physical-device screen video and resubmit for Apple App Review.
