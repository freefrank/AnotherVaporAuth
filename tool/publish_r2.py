#!/usr/bin/env python3
"""Publish release artifacts to R2 (dl.dotslash.pro) and prune stale versions.

Part of the release flow (see CLAUDE.md 发布分发): after `flutter build` has
filled dist/ and the GitHub release exists, this ships the same artifacts to
the bucket users in China can actually reach, verifies every byte landed, and
deletes the previous release's objects.

    python3 tool/publish_r2.py            # dry-run: says what it WOULD do
    python3 tool/publish_r2.py --apply    # do it

Design notes, learned the hard way:

- Every upload is READ BACK and sha256-compared. `wrangler r2 object put`
  exiting 0 is not proof of anything a user will download (2026-08-10's cn
  APK went up with a full byte-for-byte verification and that discipline
  stays).
- Pruning needs a listing, and wrangler has no `list` — so the script keeps
  its own inventory as `r2-manifest.json` IN the bucket: upload, verify,
  delete (previous inventory minus current), then write the new inventory.
  KEEP_ALWAYS survives every prune (version_dev.json is the staging table
  dev builds point at; deleting it would silence every dev-build banner).
- Dry-run is the default. The only destructive step (delete) prints its exact
  victim list either way.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUCKET = "ava"
PUBLIC = "https://dl.dotslash.pro"
INVENTORY = "r2-manifest.json"

# Objects a prune must never touch, whatever any inventory says.
KEEP_ALWAYS = {INVENTORY, "version_dev.json"}

# (dist filename template, content-type). Absent files are skipped with a
# warning — the cn APK is the one artifact this flow exists for, so IT is
# required; desktop artifacts ride along when present.
ARTIFACTS = [
    ("AVA-v{v}-cn.apk", "application/vnd.android.package-archive", True),
    ("AVA-v{v}-windows-x64-setup.exe",
     "application/vnd.microsoft.portable-executable", False),
    ("AVA-v{v}-windows-x64-portable.exe",
     "application/vnd.microsoft.portable-executable", False),
    ("AVA-v{v}-linux-x86_64.AppImage", "application/octet-stream", False),
    ("AVA-v{v}-macos-arm64.dmg", "application/x-apple-diskimage", False),
]


def sh(args: list[str], **kw) -> subprocess.CompletedProcess:
    args[0] = shutil.which(args[0]) or args[0]
    return subprocess.run(args, check=True, capture_output=True, **kw)


def wrangler(*args: str) -> subprocess.CompletedProcess:
    return sh(["npx", "wrangler", *args], cwd=ROOT)


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def pubspec_version() -> str:
    text = (ROOT / "app/pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.M)
    if not m:
        sys.exit("app/pubspec.yaml has no parseable release version")
    return m.group(1)


def fetch_inventory() -> list[str]:
    """Previous release's object list; [] when absent (first run)."""
    try:
        out = wrangler("r2", "object", "get", f"{BUCKET}/{INVENTORY}",
                       "--remote", "--pipe").stdout
        data = json.loads(out)
        return [o for o in data.get("objects", []) if isinstance(o, str)]
    except (subprocess.CalledProcessError, json.JSONDecodeError):
        print(f"  (no readable {INVENTORY} in the bucket — nothing to prune)")
        return []


def upload_and_verify(path: Path, content_type: str, apply: bool) -> None:
    if not apply:
        print(f"  would upload {path.name}  ({path.stat().st_size >> 20} MB)")
        return
    wrangler("r2", "object", "put", f"{BUCKET}/{path.name}",
             f"--file={path}", f"--content-type={content_type}", "--remote")
    # Read back THROUGH R2 and compare. An upload nobody verified is an
    # upload nobody can trust.
    with tempfile.TemporaryDirectory(dir=ROOT / "dist") as tmp:
        downloaded = Path(tmp) / "download.verify"
        wrangler("r2", "object", "get", f"{BUCKET}/{path.name}",
                 "--remote", f"--file={downloaded}")
        remote = sha256_file(downloaded)
    local = sha256_file(path)
    if remote != local:
        sys.exit(f"VERIFY FAILED for {path.name}: local {local[:16]}… "
                 f"remote {remote[:16]}… — bucket now holds a corrupt object!")
    print(f"  uploaded + verified {path.name}  sha256 {local[:16]}…")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--apply", action="store_true",
                    help="actually upload/delete (default: dry-run)")
    ap.add_argument("--version", default=None,
                    help="override the version read from app/pubspec.yaml")
    ap.add_argument("--desktop-only", action="store_true",
                    help="replace desktop artifacts only; no Android upload or pruning")
    args = ap.parse_args()
    v = args.version or pubspec_version()
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"== publish_r2 {mode} · version {v} · bucket {BUCKET} ==")

    uploads: list[tuple[Path, str]] = []
    for tmpl, ctype, required in ARTIFACTS:
        if args.desktop_only and tmpl.endswith('.apk'):
            continue
        p = ROOT / "dist" / tmpl.format(v=v)
        if p.exists():
            uploads.append((p, ctype))
        elif required or args.desktop_only:
            sys.exit(f"missing required artifact: {p} — build it first")
        else:
            print(f"  skip (absent): {p.name}")
    print(f"-- uploading {len(uploads)} artifact(s)")
    if args.desktop_only and args.apply:
        inventory = set(fetch_inventory())
        if not all(p.name in inventory for p, _ in uploads):
            sys.exit("desktop-only requires existing same-version inventory entries")
    for p, ctype in uploads:
        upload_and_verify(p, ctype, args.apply)

    if args.desktop_only:
        # Same-version desktop refresh: existing inventory and Android objects
        # remain valid (checked before uploading).
        print("  desktop refresh complete; inventory and Android unchanged")
        return

    print("-- pruning")
    current = {p.name for p, _ in uploads}
    stale = [o for o in fetch_inventory()
             if o not in current and o not in KEEP_ALWAYS]
    if not stale:
        print("  nothing stale")
    for obj in stale:
        if args.apply:
            wrangler("r2", "object", "delete", f"{BUCKET}/{obj}", "--remote")
            print(f"  deleted {obj}")
        else:
            print(f"  would delete {obj}")

    if args.apply:
        inv = json.dumps({"version": v, "objects": sorted(current)},
                         indent=2).encode()
        with tempfile.NamedTemporaryFile(dir=ROOT / "dist",
                                         suffix=".json") as tmp:
            Path(tmp.name).write_bytes(inv)
            wrangler("r2", "object", "put", f"{BUCKET}/{INVENTORY}",
                     f"--file={tmp.name}", "--content-type=application/json",
                     "--remote")
        print(f"  inventory written ({len(current)} objects)")

    print("-- next (manual, in the dotslashpro repo)")
    print(f"   1. site.ts: TAG/VERSION -> v{v[:v.rindex('.')]} / v{v}, "
          "then push (Pages deploys)")
    print(f"   2. curl -sI {PUBLIC}/AVA-v{v}-cn.apk   # expect 200 + apk type")
    print("   3. worker version endpoint: bump table, wrangler deploy, "
          "curl /v1/version")


if __name__ == "__main__":
    main()
