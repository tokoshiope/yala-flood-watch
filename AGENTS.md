# Yala Flood Watch — AI Team Operating Charter (Workspace Rules v3.0)

> **Operating Model:** Life-Safety Evidence-First 5-Agent Charter (v3.0 · upgraded from v2.0 with Mandatory Error Memory, Verify-Fix-Reverify Loop, Strict Data Provenance & Lean Hygiene)
> **Product:** **แจ้งเตือนน้ำท่วมยะลา (Yala Flood Watch)** — iOS-First Early Flood Warning App & Multi-Source Telemetry Pipeline (เฉพาะจังหวัดยะลา · 8 อำเภอ · `province_code=95`)
> **Pricing Model:** 100% Free Forever (Public-Interest Civic App · Zero IAP · Zero Ads · Zero UGC · Zero Server PII · Near-Zero Marginal Cost)
> **Mission:** One Founder. AI-powered. Turning verified hydrological & terrain data into accurate, official-grade 2–24 hour early flood warnings for every household in Yala Province.

---

## 1. Team Roles & Separation of Concerns

| Role | Who | Responsibilities |
|---|---|---|
| **CEO + Product Owner** | **Founder (Human)** | Sets product vision, approves all **3 Human Gates**, owns Apple Developer / GitHub / Supabase / Firebase accounts, and coordinates official verification with ปภ.ยะลา / เทศบาลนครยะลา. |
| **Orchestrator + PM / Dev Lead** | **Main Agent** | Checks `docs/lessons-learned.md` before every change, plans tasks in `docs/tasks.md`, authors specs in `docs/specs/`, maintains multi-source pipeline (`backend/`), Flutter iOS-First app (`mobile/app/`), static web pages (`web/`), automated tests, and living files. |
| **QA / Hydrology & Security Reviewer** | **Independent Subagent (Separate Context)** | Audits `formula_version = 5` math & Python↔Dart parity, Zone A/B/C terrain exposure, GeoJSON topology (zero overlap/gap), ICT/UTC freshness, fail-closed guarantees, data provenance/zero-hallucination compliance, PDPA, and iOS HIG/375pt/1.35× accessibility. **MUST run in a separate subagent context from the code author** for all high-risk changes and every release. |
| **DevOps / Release Agent** | **Subagent or Dedicated Run** | Manages `.github/workflows/`, atomic immutable CDN snapshot publishing, Xcode/TestFlight builds (`release_preflight.sh`), and pipeline failure alerting. |
| **Post-Launch Roles** *(Deferred until live users)* | Future Subagents | Elderly/Yawi Accessibility, Municipal Coordination, Reliability Monitoring. |

---

## 2. Mandatory Living Files & Auto-Update Protocol

**CRITICAL RULE:** Agents persist durable institutional memory through repository files rather than chat history. Before ending any work turn that completes a task, modifies code/registries/GeoJSON, fixes a bug, runs a QA audit, or records a decision, the agent **MUST** update the relevant living files:

1. **`docs/lessons-learned.md` (Mandatory Error Memory — READ FIRST, UPDATE ON EVERY DEFECT):**
   - **Before coding:** Scan relevant entries (`LL-XXX`) in the domain you are touching (formulas, station datums, GeoJSON, UI charts/Dark Mode/375pt, iOS App Store, CI).
   - **After any bug/QA finding:** Append a new `LL-XXX` record with Date, Domain, Mistake/Symptom, Root Cause, Fix Applied, and Permanent Guardrail/Regression Test.
2. **`docs/data-provenance.md` (Source Attribution & Number Ledger):**
   - Every dataset, hydrological threshold, coordinate, boundary file, emergency contact, shelter, and safety rule **MUST** be listed with its authoritative source, URL/agency, license, and verification status (`verified` vs `pending_ddpm_verify` vs `datum_unverified` vs `is_historical_unconfirmed`).
3. **`docs/tasks.md` (Living Task Board):**
   - Mark completed items `[x]` with ISO date and **concrete, tool-verified evidence** (exact `pytest` / `flutter test` / `flutter analyze` / geometry-audit / `plutil` outputs).
4. **`docs/decisions.md` (Living Decision Log):**
   - Append a sequential entry (`DEC-XXX`) for every product, formula, data-source, boundary, architecture, safety, or legal decision with Date, Status, Decision, Rationale, and Affected Files.
5. **`docs/specs/spec-<feature>.md` (Feature Specs):**
   - Draft a focused specification before coding any major user-facing feature, formula version bump, or high-risk integration.
6. **`docs/qa/audit-YYYY-MM-DD-*.md` (Archived Verification Evidence):**
   - Persist every Independent QA Audit and Re-Audit report with exact commands run, verbatim pass/fail metrics, defect severity breakdown, and explicit `PASS` / `HOLD` verdict before Gate 3.

---

## 3. Mandatory Human Gates (STOP & Ask Founder Approval)

The AI team **MUST pause and obtain explicit Founder approval** before crossing any of these 3 gates:

1. **Gate 1 — Spec & Scope Gate:** Before adding major user-facing features, expanding beyond Yala Province (`province_code=95`), or changing the 100% Free / 0% UGC civic model.
2. **Gate 2 — Architecture / Schema / Formula / Emergency-Data / Legal Gate:** Before changing database schemas/RLS, modifying core Alert Engine thresholds/weights or `formula_version`, adding paid external APIs, changing verified emergency phone numbers/official shelter status, or publishing PDPA/Privacy/Disclaimer legal copy.
3. **Gate 3 — Pre-Deploy & App Store Release Gate:** Before pushing breaking production changes, running irreversible data migrations, or submitting any build to TestFlight / Apple App Store / Google Play. **Gate 3 strictly requires an Independent QA/Reviewer `PASS` sign-off first.**

---

## 4. Strict Verify → Fix → Re-Verify Loop & Independent QA Rule

Never rely solely on the code-writing agent to verify life-safety, mathematical, geographic, or UI work:

1. **Self-Verification After Final Edit (Mandatory):** No agent may claim "fixed" or "done" without running actual verification commands **after the last file edit** (zero stale test results):
   - Backend: `backend/.venv/bin/pytest -q backend/tests` + `publish_supabase.py --dry-run` + `notify_fcm.py --dry-run`
   - Flutter: `flutter analyze` (`0 issues`) + `flutter test` (`100% pass`, including 375pt / 1.35× text-scale / Light & Dark theme regression tests)
   - GeoJSON Topology (whenever geo assets change): automated area-conservation (`<= 0.1%` discrepancy), zero pairwise polygon overlap, zero self-intersection, and valid Yala bbox check
   - iOS Plist/Entitlements (whenever `ios/` changes): `plutil -lint`
2. **Independent QA Subagent (`invoke_subagent` — Separate Context):**
   - For all formula upgrades, boundary rebuilds, UI overhauls, and pre-release builds, invoke an **independent read-only QA subagent** to audit code, math parity, data provenance, zero-hallucination compliance, security, and accessibility.
   - If Independent QA returns `HOLD` or finds any `BLOCKER` / `HIGH` / `MEDIUM` defect:
     1. Fix every finding cleanly.
     2. Add a permanent automated regression test.
     3. Record the defect in `docs/lessons-learned.md`.
     4. Re-run all verification suites.
     5. Invoke a **fresh Independent Re-Audit** and archive both the initial audit and final `PASS` re-audit evidence in `docs/qa/audit-YYYY-MM-DD-*.md`.

---

## 5. Zero-Hallucination & Strict Data Provenance Guardrails

1. **No Guessing, No Fabricated Numbers, No Silent Extrapolation:**
   - Every displayed metric, threshold, coordinate, boundary, phone number, shelter, and safety step **MUST** originate from a verified source logged in `docs/data-provenance.md`.
   - If an upstream datum is suspect (e.g., `FOP045` bank-vs-level gap) or an official contact/shelter is awaiting confirmation, mark it explicitly (`datum_unverified: true`, `pending_ddpm_verify`, `is_historical_unconfirmed: true`) and inform the Founder — NEVER invent or smooth over missing facts.
2. **Yala-Only Geographic Precision & Official Thai Tone:**
   - Strictly serve Yala Province (`province_code = "95"`, 8 amphoes, 58 tambons, 449 villages) within bbox `lat 5.5–7.2`, `lon 100.5–101.9` and `Asia/Bangkok` (UTC+7) timestamps everywhere.
   - All citizen-facing alert titles, level descriptions, and guidance copy **MUST** use formal, concise, easy-to-understand official Thai (ภาษาราชการ กระชับ เข้าใจง่าย) aligned with กรม ปภ. / สสน. standards — zero slang or technical formula jargon in user-facing UI, synced across all 4 languages (`th`, `en`, `zh`, `ms`).
3. **Multi-Source Fail-Closed Integrity:**
   - **Tier A (Primary Official Telemetry):** ThaiWater Waterlevel (14 stations — Fail-Closed), Rain 24h (87 gauges across all 8 amphoes), Bang Lang Dam (`analyst/dam`, EGAT/RID).
   - **Tier B (Open Scientific Forecasts):** Open-Meteo Weather 72h & Past 7d (`API_7d`) + GloFAS v4 7-day river discharge (`CC BY 4.0`).
   - Primary water telemetry failure, corruption, out-of-bbox coordinates, or stale data MUST exit non-zero and NEVER overwrite a valid snapshot.
4. **Offline-First Resilience & Near-Zero Marginal Cost:**
   - Precompute snapshots once per 10-minute cycle via GitHub Actions Cron → atomic immutable Supabase CDN + SHA-256 `manifest.json`.
   - Mobile clients verify `content_hash` + `province_code == "95"`, cache snapshots locally, and embed core App/Evacuation Guides + emergency hotlines + shelters 100% offline inside the app bundle.
5. **Privacy-by-Design, PDPA & 0% UGC / Data Not Collected:**
   - Zero server-side PII, zero UGC uploads, `PrivacyInfo.xcprivacy` = `Data Not Collected`.
   - Request iOS location permission (`When In Use` only) strictly after clear Thai PDPA consent; keep preferences & pins local-first with one-tap "ลบข้อมูลทั้งหมดของฉัน (PDPA)" full wipe.
6. **Continuous Lean Hygiene (Zero-Bloat Rule):**
   - Whenever a feature, endpoint, or formula version is superseded or deprecated, delete dead source files, unused localization strings, legacy formula branches, and stale snapshot archives in the same release cycle so the binary and repository stay lean, auditable, and bug-free.
