#!/usr/bin/env python3
"""Yala Flood Watch — Atomic Immutable Supabase Storage CDN Publisher (Phase 2).

Upload order (fail-closed, zero torn reads):
  1. Verify local latest.json SHA-256 matches manifest.json content_hash.
  2. Upload immutable snapshot-<ts>-<hash>.json  (Cache-Control: max-age=31536000, immutable)
  3. Upload latest.json                           (Cache-Control: max-age=300)
  4. Upload manifest.json LAST                    (Cache-Control: max-age=120)

Usage:
  python backend/publish_supabase.py --snapshot-dir backend/output --dry-run
  SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... python backend/publish_supabase.py --snapshot-dir backend/output
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import requests

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))
import pipeline as P  # noqa: E402


def verify_snapshot_bundle(snapshot_dir: Path) -> tuple[dict, Path, Path, Path]:
    manifest_path = snapshot_dir / "manifest.json"
    latest_path = snapshot_dir / "latest.json"
    if not manifest_path.exists() or not latest_path.exists():
        raise P.ValidationError(f"Missing manifest.json or latest.json in {snapshot_dir}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    latest = json.loads(latest_path.read_text(encoding="utf-8"))

    expected_hash = manifest.get("content_hash")
    actual_hash = P.content_hash(latest)
    if not expected_hash or actual_hash != expected_hash:
        raise P.ValidationError(
            f"SHA-256 mismatch (fail-closed): manifest={expected_hash!r} actual={actual_hash!r}"
        )

    snap_name = manifest.get("snapshot")
    snap_path = snapshot_dir / snap_name if snap_name else latest_path
    if not snap_path.exists():
        snap_path = latest_path

    if latest.get("province", {}).get("code") != "95":
        raise P.ValidationError("Snapshot province_code != 95 (Yala-only guardrail)")
    if len(latest.get("amphoes", [])) != 8:
        raise P.ValidationError("Snapshot must cover all 8 amphoes of Yala")

    return manifest, snap_path, latest_path, manifest_path


def _upload_object(
    supabase_url: str,
    service_key: str,
    bucket: str,
    object_path: str,
    file_path: Path,
    cache_control: str,
) -> None:
    url = f"{supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{object_path.lstrip('/')}"
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": cache_control,
        "x-upsert": "true",
    }
    resp = requests.post(url, headers=headers, data=file_path.read_bytes(), timeout=20)
    if resp.status_code not in (200, 201):
        raise P.ValidationError(f"Supabase upload failed ({resp.status_code}) for {object_path}: {resp.text[:200]}")


def _purge_expired_reports(supabase_url: str, service_key: str) -> int | None:
    """Invoke PDPA 90-day retention RPC `purge_expired_reports` (best-effort, non-fatal)."""
    base = supabase_url.strip().rstrip("/")
    if not base.startswith("https://"):
        return None
    url = f"{base}/rest/v1/rpc/purge_expired_reports"
    headers = {
        "Authorization": f"Bearer {service_key}",
        "apikey": service_key,
        "Content-Type": "application/json",
    }
    try:
        resp = requests.post(url, headers=headers, json={}, timeout=10)
        if resp.status_code == 200:
            val = resp.json()
            return int(val) if isinstance(val, int) and not isinstance(val, bool) else 0
    except Exception:
        return None
    return None


def publish(snapshot_dir: Path, bucket: str = "snapshots", dry_run: bool = False) -> int:
    try:
        manifest, snap_path, latest_path, manifest_path = verify_snapshot_bundle(snapshot_dir)
        uploads = [
            (f"history/{snap_path.name}", snap_path, "public, max-age=31536000, immutable"),
            ("latest.json", latest_path, "public, max-age=300, stale-while-revalidate=600"),
            ("manifest.json", manifest_path, "public, max-age=120"),
        ]
        if dry_run:
            print(
                f"DRY_RUN_OK bucket={bucket} hash={manifest['content_hash'][:12]} "
                f"stations={manifest.get('count')} amphoes={manifest.get('amphoe_count')} "
                f"files={[u[0] for u in uploads]}"
            )
            return 0

        supabase_url = os.environ.get("SUPABASE_URL", "").strip()
        service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        if not supabase_url or not service_key:
            print("PUBLISH_SKIPPED: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not set", file=sys.stderr)
            return 1
        if not supabase_url.startswith("https://"):
            raise P.ValidationError("SUPABASE_URL must use https://")

        for obj_path, fpath, cc in uploads:
            _upload_object(supabase_url, service_key, bucket, obj_path, fpath, cc)

        purged = _purge_expired_reports(supabase_url, service_key)
        purge_note = f" purged_expired_reports={purged}" if purged is not None else ""
        print(f"PUBLISHED_OK bucket={bucket} hash={manifest['content_hash'][:12]} files={len(uploads)}{purge_note}")
        return 0
    except Exception as e:
        print(f"PUBLISH_FAIL_CLOSED: {e}", file=sys.stderr)
        return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Atomic Supabase Storage CDN Publisher")
    parser.add_argument("--snapshot-dir", default=str(BASE_DIR / "output"))
    parser.add_argument("--bucket", default="snapshots")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv if argv is not None else sys.argv[1:])
    return publish(Path(args.snapshot_dir), bucket=args.bucket, dry_run=args.dry_run)


if __name__ == "__main__":
    raise SystemExit(main())
