# Feature Spec — Option C: Real Smart SOS Dispatch & Tier C Community Flood Reports (v1.0)

- **Decision Ref:** `DEC-019` (Gate 2 Approved by Founder on 2026-11-24)
- **Target Release:** `1.0.0+7` (iOS App Store Production Release)
- **Scope:** Yala Province ONLY (`province_code = "95"`, 8 amphoes, `lat 5.5–7.2`, `lon 100.5–101.9`)

---

## 1. Objectives & Life-Safety Guardrails

1. **Unlock Real SOS Dispatch (Zero-Server PII):**
   - Replace the TestFlight local-only SOS placeholder with an actionable, offline-resilient **Smart SOS Dispatch** workflow.
   - Build a structured, localized emergency message containing: assistance type, exact GPS coordinates (`±accuracy`), direct Google Maps link (`https://maps.google.com/?q=lat,lng`), offline-computed Amphoe/Tambon & ground elevation (MSL) vs nearest station water level, optional contact phone, optional short note, and ICT (`UTC+7`) timestamp.
   - Dispatch immediately through user-controlled real channels:
     - **Emergency SMS (`sms:?body=...`)** — functions even when mobile internet drops during severe floods; uses RFC 3986 `%20` encoding (never `+`) for iOS Messages compatibility.
     - **LINE Share (`https://line.me/R/share?text=...`)** — sends directly to family, rescue groups, or Official Accounts.
     - **1-Tap Copy + Official LINE Shortcuts (`@1784DDPM`, `@yalacity`)** — copies the full SOS message to clipboard before opening the Official Account chat.
     - **1-Tap Emergency Call (`1784`, `073-203559`, `1669`)** — displayed directly inside the dispatch sheet alongside large-font coordinates so callers can read coordinates aloud to dispatchers.
   - Keep full SOS history and optional phone/notes **strictly local on-device** (Zero PII uploaded to any server for SOS).
   - Retain unambiguous non-official life-safety disclaimers directing users in immediate danger to call `1784` / `073-203559` / `1669`.

2. **Activate Tier C Community Flood Reports (Anonymous, PDPA-Compliant):**
   - Connect the app to the existing Supabase RLS schema (`supabase/migrations/0001_initial_yala_flood_schema.sql`):
     - `POST /rest/v1/rpc/submit_community_report` (rate-limited: 1 report / `device_hash` / 60 minutes, Yala bbox enforced).
     - `GET /rest/v1/public_community_reports` (anonymized view without `device_hash`).
   - **Zero-PII PDPA Safeguards:**
     - Never transmit phone number, user name, or exact home coordinates.
     - Round coordinates client-side to **3 decimal places (~110m)** before upload (matching server-side rounding).
     - Generate a random local salt stored in `SharedPreferences` (`yala_flood_community_salt_v1`) and hash it with pure-Dart SHA-256 (`64`-char hex `device_hash`).
     - Wipe both `communityDeviceSaltKey` and `communityLastReportAtKey` in `LocalStore.deleteAllUserData()` ("ลบข้อมูลของฉันทั้งหมด (PDPA)").
     - Auto-expire on server after **90 days** (`expires_at`), enforced via `purge_expired_reports()` in GitHub Actions.
     - Fail-closed if `YALA_SUPABASE_ANON_KEY` or HTTPS Supabase URL is absent (honest UI notice, never fakes upload).

3. **Backend Pipeline Tier C Ingestion (`backend/pipeline.py`):**
   - When `SUPABASE_URL` (HTTPS) and `SUPABASE_SERVICE_ROLE_KEY` are configured in GitHub Actions, query verified recent reports (`created_at >= now - 60m` AND `trust_score >= 3`) per amphoe and feed `community_reports_60m` into `compute_alert_v3()`.
   - Graceful degradation: if unconfigured or unreachable, fallback to `0` without failing primary Tier A water telemetry.
   - Trigger `purge_expired_reports` RPC during GitHub Actions runs when Supabase secrets are present so 90-day PDPA deletion runs automatically.

---

## 2. Acceptance Criteria

- [ ] `Info.plist` includes `sms` in `LSApplicationQueriesSchemes` and passes `plutil -lint`.
- [ ] `SosDispatchService` produces `%20`-encoded `sms:` URIs (zero literal `+` spaces), HTTPS `line.me/R/share` URIs, and localized messages in all 4 languages (`th`/`en`/`zh`/`ms`).
- [ ] `CommunityReportService` rounds coordinates to 3 decimals, rejects out-of-Yala coordinates, enforces HTTPS-only, sends 64-char SHA-256 `device_hash`, never includes phone/name in payload, handles 60-min rate limit cleanly, and fails closed when unconfigured.
- [ ] `LocalStore.deleteAllUserData()` clears all user keys including `communityDeviceSaltKey` and `communityLastReportAtKey`.
- [ ] `SosScreen` passes Dark Mode contrast, 4-language zero-Thai-leakage checks, and widget tests.
- [ ] `backend/pipeline.py` wires `community_reports_by_amphoe` (`trust_score >= 3`) into `normalize()` & `build_amphoe_summaries()`, preserving `formula_version = 3` Python ↔ Dart parity and never making Tier C the sole trigger for Level 5 evacuation.
- [ ] Independent QA Subagent audit verdict = `PASS`.
