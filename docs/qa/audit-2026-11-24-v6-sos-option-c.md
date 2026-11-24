# Independent QA, Hydrology & Security Audit — Yala Flood Watch v1.0.0+7 (Option C: Smart SOS Dispatch & Tier C Community Flood Reports)

- **Date:** 2026-11-24
- **Auditor:** Independent QA / Hydrology & Security Reviewer Subagent (Separate Read-Only Context)
- **Initial Verdict:** `HOLD` (0 BLOCKER, 2 HIGH, 3 MEDIUM, 6 LOW)
- **Re-Audit Verdict:** **`PASS`** (0 BLOCKER, 0 HIGH, 0 MEDIUM, 0 LOW open)

---

## 1. Remediated Findings & Verification

| ID | Category | Finding | Remediation & Verification |
|---|---|---|---|
| **HIGH-1** | Life-Safety UX | `ScaffoldMessenger.showSnackBar` rendered behind modal bottom sheet (`_SosDispatchSheet`), giving zero visible feedback on Copy or SMS/LINE fallback | Converted `_SosDispatchSheet` to a `StatefulWidget` with a pinned sticky confirmation banner above the scrollable `ListView` driven by `Future<String?>` action callbacks (`sos_screen.dart:603-726`). Verified by widget test (`sos_and_community_test.dart:335-361`) asserting clipboard payload + visible banner + `dispatchedVia == 'clipboard'` (**CLOSED**). |
| **HIGH-2** | WCAG AA Contrast | Light-mode LINE `OutlinedButton` (`#06C755` = `2.26:1`) and Dark-mode dispatch sheet SOS icon (`#B71C1C` = `2.60:1`) failed contrast targets | Changed Light-mode `lineColor` to `#04783A` (`5.60:1` white / `5.07:1` card; Dark `#4ADE80` `9.80:1`) and Dark-mode sheet header icon to `#FF8A80` (`7.48:1`) (**CLOSED**). |
| **MEDIUM-1** | Backend Security | `backend/publish_supabase.py` transmitted `SUPABASE_SERVICE_ROLE_KEY` without enforcing `https://` | Added `https://` guard in both `publish()` and `_purge_expired_reports()` (`publish_supabase.py:81-83, 121-122`), excluded `bool` from purge count, and added pytest `test_publish_supabase_rejects_non_https_before_sending_service_key` (**CLOSED**). |
| **MEDIUM-2** | Data Integrity / UI Sync | `_submitCommunityReport()` attached GPS from one district when user picked another district; `DropdownButtonFormField.initialValue` lacked `ValueKey` | Only uses GPS when `evaluateCoordinates(...).amphoeTh == _communityAmphoe` (otherwise district centroid), and added `ValueKey('community-amphoe-$selectedAmphoe')` (`sos_screen.dart:347-378, 1423`) (**CLOSED**). |
| **MEDIUM-3** | PDPA / App Store Privacy | Thai `web/privacy.html` §2 still referenced community reports "in the future"; `PrivacyInfo.xcprivacy` & `app-store-metadata.md` omitted `OtherUserContent` for optional community notes | Synced Thai & English `web/privacy.html`, declared `NSPrivacyCollectedDataTypeOtherUserContent` (`Linked=false`, `Tracking=false`, `PurposeAppFunctionality`) in `PrivacyInfo.xcprivacy` (`plutil -lint OK`), and updated `docs/launch/app-store-metadata.md` §4 (**CLOSED**). |
| **LOW-1..6** | Resilience & Hygiene | Post-consent `mounted` check, `initState` reset-version sync, verified `launchUrl` attribution for `'line'`/`'call'`, expanded SHA-256 vectors (56B/64B/Thai UTF-8), surrogate-safe `runes.take(280)` truncation, Yala amphoe whitelist in `fetch_community_reports_60m`, and Light-mode FB (`#145DBF` `6.27:1`) + `SosStatus.pending` (`#9A6700` `4.87:1`) contrast | All 6 items fixed and independently verified (**CLOSED**). |

---

## 2. Automated Verification Evidence

- `backend/.venv/bin/pytest -v backend/tests/test_pipeline.py` → **47/47 PASSED**
- `plutil -lint mobile/app/ios/Runner/Info.plist mobile/app/ios/Runner/PrivacyInfo.xcprivacy mobile/app/ios/Runner.xcodeproj/project.pbxproj` → **OK**
- `backend/.venv/bin/python backend/publish_supabase.py --snapshot-dir backend/output --dry-run` → **`DRY_RUN_OK`**
- `backend/.venv/bin/python backend/notify_fcm.py --snapshot-dir backend/output --dry-run` → **`FCM_DRY_RUN_OK`**
- `flutter analyze --no-pub` → **0 issues**
- `flutter test --no-pub` → **77/77 PASSED** (incl. NIST RFC 6234 56B/64B/UTF-8 Thai SHA-256 vectors, `%20`-encoded iOS `sms:` URIs, HTTPS `line.me/R/share`, PDPA ~110m rounding & full 8-key wipe, and Dark Mode `_SosDispatchSheet` sticky banner regression).

---

## 3. Gate 3 Readiness Verdict
**`PASS`** — Approved from QA, Hydrology, Security, WCAG, and PDPA perspectives to proceed to **Founder Gate 3 Release Approval** (GitHub Push, TestFlight `1.0.0+7` IPA upload, and Apple App Store submission).
