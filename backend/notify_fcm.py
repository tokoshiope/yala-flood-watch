#!/usr/bin/env python3
"""
Yala Flood Watch — Automated FCM HTTP v1 Topic Push Dispatcher.

Reads verified `backend/output/latest.json` + `manifest.json` (fail-closed on hash mismatch),
identifies amphoes where `assessment.should_push == True` and `assessment.level >= 2`,
applies 30-minute cooldown (with immediate escalation when alert level increases),
and dispatches citizen-friendly push notifications (zero technical formula jargon)
to ASCII FCM topics matching `mobile/app/lib/services/notification_service.dart`:
  - `yala_flood_all` (provincial max alert)
  - `yala_flood_<amphoe_slug>` (per-amphoe alert)

Credentials:
  - Set `FIREBASE_SERVICE_ACCOUNT_JSON` env var (JSON string of Google Service Account)
    when sending real pushes via FCM HTTP v1 API.
  - Use `--dry-run` in CI/local verification without credentials.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import requests

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))
import pipeline as P  # noqa: E402

ICT = timezone(timedelta(hours=7))
COOLDOWN_SECONDS = 30 * 60       # 30 minutes (matching AlertEngine)
HYSTERESIS_SECONDS = 2 * 3600    # 2 hours (matching AlertEngine hysteresis window)

TOPIC_ALL_YALA = "yala_flood_all"
AMPHOE_TOPIC_MAP: dict[str, str] = {
    "เมืองยะลา": "yala_flood_mueang_yala",
    "รามัน": "yala_flood_raman",
    "ยะหา": "yala_flood_yaha",
    "กรงปินัง": "yala_flood_krong_pinang",
    "เบตง": "yala_flood_betong",
    "บันนังสตา": "yala_flood_bannang_sata",
    "ธารโต": "yala_flood_than_to",
    "กาบัง": "yala_flood_kabang",
}

LEVEL_TITLE_PREFIX: dict[int, str] = {
    2: "เฝ้าระวังน้ำท่วม",
    3: "เตือนภัยน้ำท่วม",
    4: "เตือนภัยสูง",
    5: "อันตรายอพยพด่วน",
}


class NotifyError(RuntimeError):
    """Fail-closed error for snapshot integrity or FCM configuration issues."""


def topic_for_amphoe(amphoe_th: str | None) -> str:
    if not amphoe_th:
        return TOPIC_ALL_YALA
    return AMPHOE_TOPIC_MAP.get(amphoe_th, TOPIC_ALL_YALA)


def verify_snapshot_integrity(snapshot_dir: Path) -> dict[str, Any]:
    latest_path = snapshot_dir / "latest.json"
    manifest_path = snapshot_dir / "manifest.json"
    if not latest_path.is_file() or not manifest_path.is_file():
        raise NotifyError(f"Missing latest.json or manifest.json in {snapshot_dir}")

    payload = json.loads(latest_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_hash = manifest.get("content_hash")
    actual_hash = P.content_hash(payload)
    if not expected_hash or actual_hash != expected_hash:
        raise NotifyError(
            f"Fail-closed: content_hash mismatch ({str(actual_hash)[:12]} != {str(expected_hash)[:12]})"
        )
    if payload.get("province", {}).get("code") != "95":
        raise NotifyError("Fail-closed: snapshot province_code != 95")
    if not isinstance(payload.get("amphoes"), list) or len(payload["amphoes"]) != 8:
        raise NotifyError("Fail-closed: snapshot must contain all 8 Yala amphoes")
    return payload


def load_state(state_path: Path | None) -> dict[str, Any]:
    if state_path is None or not state_path.is_file():
        return {}
    try:
        data = json.loads(state_path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_state(state_path: Path | None, state: dict[str, Any]) -> None:
    if state_path is None:
        return
    state_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = state_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, state_path)


def should_send_topic(
    topic: str,
    level: int,
    state: dict[str, Any],
    now_ts: float,
) -> bool:
    prev = state.get(topic)
    if not isinstance(prev, dict):
        return True
    prev_level = int(prev.get("level", 0))
    prev_ts = float(prev.get("sent_at", 0.0))
    elapsed = now_ts - prev_ts
    # Once the 2-hour hysteresis window has passed, treat prior flood event as closed
    # so a historical Level 4/5 event NEVER permanently suppresses future Level 2–3 warnings.
    if elapsed >= HYSTERESIS_SECONDS:
        return True
    # Escalation bypasses cooldown immediately
    if level > prev_level:
        return True
    # Lower level within the active 2-hour hysteresis window does not re-alert
    if level < prev_level:
        return False
    return elapsed >= COOLDOWN_SECONDS


def reconcile_state(
    snapshot: dict[str, Any],
    state: dict[str, Any],
    sent_messages: list[dict[str, Any]],
    now_ts: float,
) -> dict[str, Any]:
    """Prune topics that returned to normal or expired (>2h), and record newly dispatched topics."""
    active_push_topics: set[str] = set()
    max_active_level = 0
    for amp in snapshot.get("amphoes", []):
        ass = amp.get("assessment") or {}
        lv = int(ass.get("level") or 1)
        if bool(ass.get("should_push")) and lv >= 2:
            active_push_topics.add(topic_for_amphoe(str(amp.get("amphoe") or "")))
            if lv > max_active_level:
                max_active_level = lv
    if max_active_level >= 3:
        active_push_topics.add(TOPIC_ALL_YALA)

    next_state: dict[str, Any] = {}
    for topic, rec in state.items():
        if not isinstance(rec, dict):
            continue
        prev_ts = float(rec.get("sent_at", 0.0))
        if topic in active_push_topics and (now_ts - prev_ts) < HYSTERESIS_SECONDS:
            next_state[topic] = rec

    for msg in sent_messages:
        m = msg["message"]
        next_state[m["topic"]] = {
            "level": int(m["data"]["level"]),
            "sent_at": now_ts,
            "sent_at_ict": datetime.fromtimestamp(now_ts, tz=ICT).isoformat(),
        }
    return next_state


def build_fcm_messages(
    snapshot: dict[str, Any],
    state: dict[str, Any],
    now_ts: float | None = None,
) -> list[dict[str, Any]]:
    """Build citizen-friendly FCM HTTP v1 topic payloads (zero formula/score jargon)."""
    ts = now_ts if now_ts is not None else time.time()
    messages: list[dict[str, Any]] = []
    highest_amp: dict[str, Any] | None = None

    for amp in snapshot.get("amphoes", []):
        ass = amp.get("assessment") or {}
        level = int(ass.get("level") or 1)
        should_push = bool(ass.get("should_push"))
        if not should_push or level < 2:
            continue

        amphoe_th = str(amp.get("amphoe") or "")
        topic = topic_for_amphoe(amphoe_th)
        if highest_amp is None or level > int((highest_amp.get("assessment") or {}).get("level") or 0):
            highest_amp = amp

        if not should_send_topic(topic, level, state, ts):
            continue

        prefix = LEVEL_TITLE_PREFIX.get(level, "แจ้งเตือนน้ำท่วม")
        title = f"{prefix}: อ.{amphoe_th} จ.ยะลา"
        action = str(ass.get("action_th") or "ติดตามสถานการณ์ระดับน้ำอย่างใกล้ชิด")
        lead = ass.get("lead_time_hours")
        body = f"{action} (คาดน้ำเดินทางถึงใน {lead})" if lead else action

        messages.append(_format_v1_payload(topic=topic, title=title, body=body, level=level, amphoe=amphoe_th))

    # Provincial summary topic (`yala_flood_all`) for users monitoring all 8 districts
    if highest_amp is not None:
        ass = highest_amp.get("assessment") or {}
        top_level = int(ass.get("level") or 1)
        if top_level >= 3 and should_send_topic(TOPIC_ALL_YALA, top_level, state, ts):
            amphoe_th = str(highest_amp.get("amphoe") or "")
            prefix = LEVEL_TITLE_PREFIX.get(top_level, "แจ้งเตือนน้ำท่วม")
            title = f"{prefix} จ.ยะลา (พื้นที่สูงสุด: อ.{amphoe_th})"
            body = str(ass.get("action_th") or "โปรดตรวจสอบแผนที่และเตรียมพร้อมอพยพตามประกาศ ปภ.ยะลา")
            messages.append(
                _format_v1_payload(
                    topic=TOPIC_ALL_YALA,
                    title=title,
                    body=body,
                    level=top_level,
                    amphoe=amphoe_th,
                )
            )

    return messages


def _format_v1_payload(
    *,
    topic: str,
    title: str,
    body: str,
    level: int,
    amphoe: str,
) -> dict[str, Any]:
    return {
        "message": {
            "topic": topic,
            "notification": {
                "title": title,
                "body": body,
            },
            "data": {
                "amphoe": amphoe,
                "level": str(level),
                "route": "/alerts",
            },
            "apns": {
                "headers": {"apns-priority": "10" if level >= 3 else "5"},
                "payload": {
                    "aps": {
                        "sound": "default",
                        "interruption-level": "time-sensitive" if level >= 4 else "active",
                    }
                },
            },
            "android": {
                "priority": "high" if level >= 3 else "normal",
                "notification": {
                    "channel_id": "yala_flood_alerts",
                    "sound": "default",
                },
            },
        }
    }


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _mint_oauth2_access_token(sa: dict[str, Any]) -> str:
    """Mint a short-lived Google OAuth2 Bearer token for FCM HTTP v1 using OpenSSL RS256."""
    now = int(time.time())
    header = _b64url(json.dumps({"alg": "RS256", "typ": "JWT"}, separators=(",", ":")).encode())
    claims = _b64url(
        json.dumps(
            {
                "iss": sa["client_email"],
                "scope": "https://www.googleapis.com/auth/firebase.messaging",
                "aud": sa.get("token_uri", "https://oauth2.googleapis.com/token"),
                "iat": now,
                "exp": now + 3600,
            },
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{claims}".encode("ascii")

    with tempfile.NamedTemporaryFile("w", suffix=".pem", delete=False) as kf:
        kf.write(sa["private_key"])
        key_path = kf.name
    try:
        sig = subprocess.check_output(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input,
        )
    finally:
        Path(key_path).unlink(missing_ok=True)

    assertion = f"{header}.{claims}.{_b64url(sig)}"
    resp = requests.post(
        sa.get("token_uri", "https://oauth2.googleapis.com/token"),
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion,
        },
        timeout=15,
    )
    resp.raise_for_status()
    return str(resp.json()["access_token"])


def dispatch_messages(
    messages: list[dict[str, Any]],
    *,
    dry_run: bool,
    service_account_json: str | None = None,
) -> list[str]:
    sent_topics: list[str] = []
    if not messages:
        return sent_topics

    if dry_run:
        for msg in messages:
            m = msg["message"]
            sent_topics.append(m["topic"])
        return sent_topics

    if not service_account_json:
        raise NotifyError("FIREBASE_SERVICE_ACCOUNT_JSON is required when not using --dry-run")

    sa = json.loads(service_account_json)
    project_id = sa.get("project_id")
    if not project_id:
        raise NotifyError("Service account JSON missing project_id")

    token = _mint_oauth2_access_token(sa)
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json; charset=UTF-8",
    }

    for msg in messages:
        resp = requests.post(url, headers=headers, json=msg, timeout=15)
        resp.raise_for_status()
        sent_topics.append(msg["message"]["topic"])

    return sent_topics


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Yala Flood Watch FCM HTTP v1 Topic Notifier")
    parser.add_argument("--snapshot-dir", default="backend/output", help="Directory containing latest.json & manifest.json")
    parser.add_argument("--state-file", default="", help="Optional JSON state file for 30-minute cooldown")
    parser.add_argument("--dry-run", action="store_true", help="Validate snapshot & build messages without calling FCM")
    args = parser.parse_args(argv)

    snapshot_dir = Path(args.snapshot_dir)
    state_path = Path(args.state_file) if args.state_file else None
    now_ts = time.time()

    try:
        snapshot = verify_snapshot_integrity(snapshot_dir)
        state = load_state(state_path)
        messages = build_fcm_messages(snapshot, state, now_ts=now_ts)
        sent = dispatch_messages(
            messages,
            dry_run=args.dry_run,
            service_account_json=os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON"),
        )
        if not args.dry_run:
            next_state = reconcile_state(snapshot, state, messages if sent else [], now_ts)
            save_state(state_path, next_state)
        mode = "FCM_DRY_RUN_OK" if args.dry_run else "FCM_SENT_OK"
        print(f"{mode} count={len(sent)} topics={sent}")
        return 0
    except Exception as exc:
        print(f"FCM_NOTIFY_ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
