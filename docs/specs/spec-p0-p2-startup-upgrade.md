# Spec: P0–P2 Startup Production & User-Impact Overhaul (`v1.1.0`)

> **Date:** 2026-11-27 · **Author:** Main Engineering Agent · **Status:** Implemented for Local MacBook Verification (Pre-Gate 3)
> **Scope:** Yala Province (`province_code=95`), 100% Free, 0% UGC, `Data Not Collected`, `formula_version = 5` unchanged.

---

## 1. Objectives

Address the critical reliability, ToS compliance, UX, and performance bottlenecks identified in the engineering audit so Yala Flood Watch performs reliably during real monsoon surge traffic and serves every citizen in Yala Province effectively.

## 2. Deliverables Included

### P0 — Critical Reliability & Compliance
1. **CDN-First Mobile Architecture (`Station.fromSnapshotJson`, `AlertProvider.refresh`):**
   - Load verified `latest.json` + `manifest.json` from Supabase CDN as the **primary** source for both 5-source amphoe forecasts AND all 14 stations (eliminating the N-phone thundering herd against `api-v3.thaiwater.net`).
   - Only call `ThaiWaterService.fetch()` directly when CDN is unconfigured, unreachable, or stale (`> 45 min`).
   - Never display an empty error screen when cached or bundled snapshot stations exist.
2. **Compliant Offline-Caching Basemap (`AppConfig`, `CachingTileProvider`):**
   - Replace undocumented `mt1.google.com/vt/lyrs=m` scraping with compliant **CARTO Voyager (Light) / CARTO Dark Matter (Dark)** OSM-derived public tiles with proper attribution (`© OpenStreetMap contributors · © CARTO · Yala 8 Districts`).
   - Add a zero-dependency disk-caching `CachingTileProvider` (bounded at 500 tiles, cleared by PDPA clear-cache) with a graceful offline fallback tile so Yala GeoJSON elevation & administrative layers remain readable even when cell towers go down.
3. **Push Tap Navigation & Multi-Topic Family Sync (`NotificationService`, `main.dart`, `AppShell`):**
   - Wire `FirebaseMessaging.onMessageOpenedApp`, `getInitialMessage()`, and `_onNotificationTapped` directly to in-app navigation (`/alerts` or `/station`).
   - Upgrade FCM subscription to a multi-topic set covering all watched family amphoes (up to 5 saved places) while cleanly unsubscribing stale topics and wiping on PDPA delete.
   - Clarify Local Alert vs Server Push behavior transparently in `SettingsScreen`.
4. **Backend Ops Resilience (`backend/pipeline.py`, `backend/notify_fcm.py`, `data-pipeline.yml`):**
   - Add HTTPS-only optional Dead-Man's-Switch (`OPS_HEARTBEAT_URL`) and Fail-Closed Ops Alert Webhook (`OPS_ALERT_WEBHOOK_URL`) in `pipeline.py`.
   - Persist `fcm_state.json` durably in Supabase Storage (`state/fcm_state.json`) when Supabase credentials exist (preventing GitHub Actions 7-day cache eviction from resetting cooldowns), with local file fallback.
   - Emit compact `history_7d.json` alongside `latest.json` for future thin-payload optimization.

### P1 — High-Impact UX & Performance
5. **15-Second First-Time Onboarding (`OnboardingSheet`):**
   - 2-step skippable flow (Language → Home Amphoe) that creates the user's primary `"บ้านของฉัน"` saved place and subscribes to their district's FCM topic so new users never miss Lv 2 Watch alerts.
6. **My Home & Family Watchlist (`SavedPlace`, `FamilyWatchStrip`):**
   - Support up to 5 local-only saved locations (e.g., บ้านของฉัน, บ้านพ่อแม่, โรงเรียนลูก) rendered in a compact Hero Status Strip at the top of `HomeScreen` with instant 3-second answers (Level 1–5 color, Lead Time, Zone A/B/C, 1-tap Fly-To, Voice Briefing, Share Card).
7. **Dynamic OTA Shelters & Nearest-First Sorting (`Shelter.fromJson`, `SheltersScreen`):**
   - Hydrate shelters dynamically from `snapshot.shelters` (falling back to offline `kYalaShelters`), calculate distance from the user's primary/pinned location, and sort nearest shelters first.
8. **1-Tap Share Flood Status Card (`ShareStatusSheet`):**
   - Render a clean, official-grade status summary card for LINE Share (`https://line.me/R/share`) and 1-tap Clipboard Copy — enabling organic village/family LINE group sharing with 0% UGC / 0% Server PII.
9. **Performance Optimization (`SnapshotService`, `HomeScreen`):**
   - Offload heavy GeoJSON/JSON parsing (~890 KB across 6 files) off the main UI isolate using `compute()`.
   - Move `latest.json` (329 KB) local cache from `SharedPreferences` (`NSUserDefaults`) to a dedicated file in the app cache directory (with safe `SharedPreferences` fallback for headless tests).
   - Memoize `HomeScreen` map polygons keyed by `(drillAmphoe, drillTumbon, snapshotHash, brightness, stationsSignature)`.

### P2 — Accessibility & Quantitative Validation
10. **100% Offline Voice Briefing (`VoiceBriefingService` + iOS `AVSpeechSynthesizer`):**
    - Native zero-dependency `MethodChannel` (`net.yala.floodapp/speech`) reading calm, formal flood guidance aloud in `th-TH`, `ms-MY`, `en-US`, and `zh-CN` for elderly citizens.
11. **Historical Flood Replay Backtest Harness (`backend/backtest_yala_2567_2568.py`):**
    - Deterministic replay of verified Nov 2567 & Nov 2568 Yala flood milestones + dry-day baselines through `compute_alert_v5` with archived report at `docs/qa/backtest-yala-2567-2568.md`.

## 3. Deferred Items Requiring External Accounts / Gate 3
- **Apple Critical Alerts Entitlement:** Requires manual Apple Developer Portal request & approval.
- **Android Google Play Release:** Requires Google Play Console account & keystore (can scaffold `android/` after MacBook iOS test sign-off).
- **External Production Scheduler (Cloudflare Workers / Cloud Run):** Requires Founder cloud credentials; Supabase durable state + Ops webhook are already wired and ready.
