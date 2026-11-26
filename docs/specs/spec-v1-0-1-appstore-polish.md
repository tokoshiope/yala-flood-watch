# Spec: v1.0.1+8 — App Store Guideline 2.1 Compliance & 6-Point UX/Telemetry Upgrade (`DEC-020`)

> **Date:** 2026-11-26  
> **Target Version:** `1.0.1+8` (`net.yala.floodapp`)  
> **Scope:** Yala Province only (`province_code = "95"`, 8 amphoes, 58 subdistricts, 449 villages) · 100% Free Forever · 0% UGC · 0% Server PII  

---

## 1. Objectives & Founder Directives

1. **New App Icon (Option 2 — Modernized Reference):** Full-bleed 1024×1024 No-Alpha RGB PNG featuring ringing alarm bell, bold "YALA FLOOD", mountain silhouette, white house, and layered flood waves — rendered across all 15 iOS AppIcon sizes (`AppIcon.appiconset`), `design/app-icon-1024.png`, and `web/icon-512.png`.
2. **Emergency Contacts Only (Zero SOS Messaging & Zero UGC):** Remove all SOS messaging forms, SMS/LINE dispatch sheets, Emergency-tab GPS lookup, local SOS history UI, and Community Flood Report (UGC) forms. Retain strictly the Life-Safety Disclaimer Banner and verified emergency contact channels (Phone, LINE, Facebook). Align `Info.plist`, `PrivacyInfo.xcprivacy`, `web/privacy.html`, and `docs/launch/app-store-metadata.md`.
3. **iOS Weather-Style Hourly Rain Bar Chart:** Upgrade `_RainForecastCard` in `AlertsScreen` to a horizontally scrollable vertical column bar chart with rounded top caps, Y-axis mm reference grid, rain intensity gradient, rain probability badges, and interactive tap-to-inspect readout.
4. **Water-Level Stations Hero Remaining-to-Bank + 7-Day Interactive History + 10-Min Telemetry Cadence:**
   - Lead with **ระยะเหลือถึงตลิ่ง** (`remainingToBank`) as the hero metric on station cards and `StationDetailScreen`.
   - Display real verified sensor update cadences (`สสน.`/`พพภ` = 10 min, `กฟผ.`/`ชป.` = 60 min).
   - Upgrade pipeline cron (`.github/workflows/data-pipeline.yml`) from every 15 min → **every 10 min (`*/10 * * * *`)** and reduce `latest.json` CDN cache `max-age` to `120s`.
   - Embed best-effort compact 7-day history (`history_7d`) in `latest.json` via ThaiWater `waterlevel_graph` AND fetch full-resolution 7-day history live in `StationDetailScreen` with `24 ชม.` / `3 วัน` / `7 วัน` range switching and touch/drag inspection.
5. **Village & Subdistrict (หมู่บ้าน/ตำบล) Clarity in Situation & Alerts:** Surface lowest-lying / most flood-vulnerable villages & subdistricts (computed from 449 DOPA villages + Copernicus DEM MSL vs river water level) inside amphoe situation cards, alert tiles, and station detail screens.
6. **Shelter Call Button Showing Phone Number:** Display formatted phone numbers directly on shelter call buttons (`กดโทร 073-212345`, `กดโทร 073-203559`, localized across all 4 languages with `FittedBox` overflow protection).
7. **Apple Guideline 2.1 Response Kit:** Provide complete 6-item App Review Notes and a physical-device iPhone recording script in `docs/launch/app-store-metadata.md`.

---

## 2. Verification & Gate Criteria

- `pytest -q backend/tests`: 51/51 passing (zero formula regression)
- Live pipeline dry-run & `publish_supabase.py --dry-run` + `notify_fcm.py --dry-run`: `OK` (`degraded=0`, 14/14 stations 7d history)
- `flutter analyze`: 0 issues
- `flutter test`: 83/83 passing
- `plutil -lint` on `Info.plist` and `PrivacyInfo.xcprivacy`: `OK`
- All 15 iOS AppIcon PNGs verified exact pixel dimensions & `hasAlpha: no`
- **Independent QA Audit v7 (`PASS`)** in separate subagent context before **Founder Gate 3** (Push + TestFlight Build 8 upload).
