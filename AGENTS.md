# Yala Flood Watch — AI Team Operating Charter (Workspace Rules)

> **Operating Model:** Life-Safety Hybrid Pragmatic 5-Agent (v2.0 · upgraded from `GPF Project` & `EV in 1` charters)
> **Product:** **น้ำท่วมยะลา (Yala Flood Watch)** — iOS-First Early Flood Warning App & Multi-Source Telemetry Pipeline (เฉพาะจังหวัดยะลา · 8 อำเภอ · `province_code=95`)
> **Pricing Model:** 100% Free Forever (Public-Interest Civic App · Zero IAP · Zero Ads · Near-Zero Marginal Cost)
> **Mission:** One Founder. AI-powered. Turning scattered hydrological telemetry into 2–12 hour actionable early flood warnings for every household in Yala Province.

---

## 1. Team Roles & Separation of Concerns

| Role | Who | Responsibilities |
|---|---|---|
| **CEO + Product Owner** | **Founder (Human)** | Sets product vision, approves all **3 Human Gates**, owns Apple Developer / GitHub / Supabase / Firebase accounts, and coordinates official verification with ปภ.ยะลา / เทศบาลนครยะลา. |
| **Orchestrator + PM / Dev Lead** | **Main Agent** | Breaks goals into tasks in `docs/tasks.md`, drafts feature specs in `docs/specs/`, maintains multi-source data pipeline (`backend/`), Flutter iOS-First app (`mobile/app/`), interactive iOS simulator (`mobile/preview/`), unit tests, and living files. |
| **QA / Hydrology & Security Reviewer** | **Independent Subagent (Separate Context)** | Audits `formula_version = 2` math & Python↔Dart parity, ICT/UTC timezone freshness, fail-closed pipeline guarantees, emergency contact/shelter zero-hallucination rules, PDPA/consent, and iOS App Store HIG/Accessibility compliance. **MUST run in a separate subagent context from the code author** for all high-risk changes. |
| **DevOps / Release Agent** | **Subagent or Dedicated Run** | Manages `.github/workflows/`, atomic immutable CDN snapshot publishing, Supabase RLS migrations, Xcode/TestFlight builds, and pipeline failure alerting. |
| **Post-Launch Roles** *(Deferred until live users)* | Future Subagents | UX/Elderly Accessibility & Yawi/Malay i18n, Community Report Moderation, Municipal Coordination, Analytics. |

---

## 2. Mandatory Auto-Update Protocol (Living Files)

**CRITICAL RULE:** Agents communicate durable state through repository files rather than chat memory. Before ending any work turn that completes a task, modifies code/registries, runs a QA audit, or records a decision, the agent **MUST update the relevant living files**:

1. **`docs/tasks.md` (Living Task Board):**
   - Mark completed items `[x]` with ISO date and concrete verification evidence (e.g., `pytest 20/20`, `flutter test 42/42`, live API probe count).
   - Maintain statuses (`TODO`, `IN PROGRESS`, `IN QA`, `WAITING FOUNDER`, `DONE`, `BLOCKED`) and log newly discovered risks/blockers.
2. **`docs/decisions.md` (Living Decision Log):**
   - Append a new sequential entry (`DEC-XXX`) for every product, hydrological formula, data source, architecture, stack, safety, or legal decision with: Date, Status, Decision, Rationale, and Affected Files.
3. **`docs/specs/spec-<feature>.md` (Feature Specs):**
   - Draft a focused specification before coding any new user-facing feature, formula version bump, or high-risk integration. Do NOT duplicate baseline `docs/01`–`04`.
4. **`docs/qa/audit-YYYY-MM-DD-*.md` (Independent QA Reports):**
   - Persist every Independent QA Audit and Re-Audit report with explicit `PASS` / `HOLD` verdict and tool-verified evidence before Gate 3.

---

## 3. Mandatory Human Gates (STOP & Ask Founder Approval)

The AI team **MUST pause and obtain explicit Founder approval** before crossing any of these 3 gates:

1. **Gate 1 — Spec & Scope Gate:** Before adding major user-facing features, expanding beyond Yala Province (`province_code=95`), or changing the 100% Free civic model.
2. **Gate 2 — Architecture / Schema / Formula / Emergency-Data / Legal Gate:** Before changing database schemas/RLS, modifying core Alert Score weights or `formula_version`, adding paid external APIs, changing verified emergency phone numbers/official shelter status, or publishing PDPA/Privacy/Disclaimer legal copy.
3. **Gate 3 — Pre-Deploy & App Store Release Gate:** Before pushing breaking production changes, running irreversible data migrations, or submitting any build to TestFlight / Apple App Store / Google Play. **Gate 3 strictly requires an Independent QA/Reviewer `PASS` sign-off first.**

---

## 4. Independent QA / Reviewer Rule

Never rely solely on the code-writing agent to verify life-safety or high-risk logic. Invoke an **independent subagent** (`invoke_subagent`) with a fresh read-only context to audit:
- **Core Alert Engine & Parity (`formula_version = 2`):** Exact parity between Python `backend/pipeline.py` and Dart `mobile/app/lib/services/alert_engine.dart` across all test vectors (`W + dH/dt`, `R`, `F`, `D` Bang Lang Dam lead-time, `C`, Flash Flood Override, Dam Spillway Override, Hysteresis 2h, Cooldown 30m, "ฝนอย่างเดียวไม่ Push", and 0-water-gauge amphoe อ.กาบัง).
- **Pipeline Fail-Closed & Timezone Safety:** Aware `Asia/Bangkok` (ICT, UTC+7) freshness checks verified under simulated UTC CI clocks; atomic `tmp → os.replace()` writes; deterministic `content_hash` excluding `generated_at`; graceful degradation when secondary feeds fail while failing closed if primary water telemetry is empty/corrupt/stale.
- **Zero-Hallucination Emergency Data:** Verify every emergency phone number (`1784` ปภ., `073-203559` ปภ.ยะลา, `073-212345` เทศบาลนครยะลา, `1669` กู้ชีพ, `199`, `191`) and ensure unverified shelter coordinates or amphoe numbers carry explicit `pending_ddpm_verify` flags.
- **PDPA, SOS Safety & iOS App Store Compliance:** Explicit GPS consent before location access, "ลบข้อมูลของฉัน" one-tap wipe, unambiguous "ไม่ใช่ช่องทางกู้ภัยหลัก / บันทึกในเครื่อง" SOS disclosure, valid `ios/Runner/Info.plist` usage strings, and accessible typography.

---

## 5. Non-Negotiable Life-Safety & Engineering Guardrails

1. **Yala-Only Geographic Precision:** Strictly serve Yala Province (`province_code = "95"`, 8 amphoes: เมืองยะลา, รามัน, ยะหา, กรงปินัง, เบตง, บันนังสตา, ธารโต, กาบัง) with strict bounding-box validation (`lat 5.5–7.2`, `lon 100.5–101.9`) and `Asia/Bangkok` (UTC+7) timestamps everywhere.
2. **Multi-Source Data Integrity & Verifiable Attribution:**
   - **Tier A (Primary Official Telemetry):** ThaiWater API v3 — Water Level (14 stations), Real-Time Rainfall (`rain_24h`, 87 gauges across all 8 amphoes), Bang Lang Dam hourly/daily (`analyst/dam`, EGAT/RID).
   - **Tier B (Open Scientific Forecasts):** Open-Meteo Weather Forecast (`CC BY 4.0`, 24–72h hourly rainfall for 8 amphoes) & Open-Meteo GloFAS v4 Flood API (`CC BY 4.0`, 7-day river discharge forecast for Pattani & Sai Buri rivers).
   - **Tier C (Community Signals):** Verified in-app reports (`trust_score >= 3`, max 1/user/hr) — never sole trigger for Level 5 evacuation.
   - Every displayed number **MUST** show its data source, `observed_at` ICT timestamp, and freshness/degraded badge. **Fail-Closed always** — corrupted or stale primary data must never overwrite a valid snapshot.
3. **Zero-Hallucination Emergency Data Rule:** NEVER fabricate emergency phone numbers, evacuation shelter coordinates, or official municipal claims. Separate `verified` vs `pending_ddpm_verify` strictly in `backend/registry/`. Always display clear non-official life-safety disclaimers directing users in immediate danger to call **1784** (สายด่วนนิรภัย ปภ.), **073-203559** (ปภ.ยะลา), or **1669** (เจ็บป่วยฉุกเฉิน).
4. **Near-Zero Marginal Cost & Offline-First Resilience:** Precompute snapshots once per cycle via GitHub Actions Cron and serve via static CDN + SHA-256 `manifest.json`. Mobile clients verify hash integrity and cache snapshots locally so citizens still see last known water levels, shelters, and emergency numbers during cellular/power outages.
5. **Privacy-by-Design & PDPA Compliance:** Keep user amphoe preferences, alerts, and SOS logs local-first on device. Request iOS location permission (`When In Use` only, never `Always`) ONLY after clear Thai consent explanation. Never store user GPS tracks on backend servers; provide one-tap "ลบข้อมูลของฉัน" deletion.
6. **iOS-First Engineering & Simulation Verification:** Prioritize iOS stability, Xcode build cleanliness (`mobile/app/ios/`), Cupertino/HIG polish, and elderly readability (large-font support). Maintain both automated unit/parity test suites AND a realistic **Simulation & Replay Harness** (`mobile/preview/`) so early-warning behavior can be stress-tested against Bang Lang Dam releases, flash floods, and Nov 2025-scale floods before reaching real citizens.
7. **Baseline Reference Docs:** Treat `docs/01`–`04` as authoritative baseline specifications (updated cleanly when Gate 2 approves new formula/sources) and track day-to-day execution in `docs/tasks.md`.
