#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "google-api-python-client>=2.120",
#     "google-auth>=2.28",
# ]
# ///
"""把 AAB 传上 Google Play —— 取代 play-store-mcp 的 deploy_app。

为什么不用 MCP：play-store-mcp 的 `MediaFileUpload(..., resumable=True)` 不带
chunksize，默认 100 MB，于是 85 MB 的 AAB 会压进**单个** HTTP 请求；而它建
service 时没传自定义 http，走的是 googleapiclient 的 DEFAULT_HTTP_TIMEOUT_SEC
= 60。传输本身只要 ~9 秒（实测上行 9.4 MB/s），卡住的是传完之后 Google 处理
bundle 的那段等待——超过 60 秒连接就断。包越大越必然失败：1.0.1 一次就过，
1.2.0（85 MB）三次才中，1.2.1 四次全挂。

本脚本两处都修：8 MB 分片 + socket.setdefaulttimeout(600)。

用法（uv 会按上面的 PEP 723 头自动装依赖，不污染系统 python）：

    tool/play_deploy.py status
    tool/play_deploy.py deploy 1.2.1                 # 演练，不动线上
    tool/play_deploy.py deploy 1.2.1 --apply
    tool/play_deploy.py deploy 1.2.1 --track internal --apply
    tool/play_deploy.py deploy 1.2.1 --rollout 20 --apply

演练是默认行为：不加 --apply 只做体检（文件、版本、发布说明长度、当前轨道
状态），一个字节都不上传。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import socket
import sys
import zipfile
from pathlib import Path

# 必须在 build() 之前设置：googleapiclient 的 build_http() 在自己的 docstring
# 里就写明 socket.setdefaulttimeout() 是覆盖那 60 秒默认值的唯一途径。
socket.setdefaulttimeout(600)

from google.oauth2 import service_account  # noqa: E402
from googleapiclient.discovery import build  # noqa: E402
from googleapiclient.errors import HttpError  # noqa: E402
from googleapiclient.http import MediaFileUpload  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
PACKAGE_NAME = "pro.dotslash.ava"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
CREDENTIALS = REPO / "secrets" / "anothervaporauth-edaab169cb99.json"
CHUNK_SIZE = 8 * 1024 * 1024
TRACKS = ("internal", "alpha", "beta", "production")
# 每语言上限。超了不是截断，是整个 commit 被 403 拒。
NOTES_LIMIT = 500


def die(msg: str) -> None:
    print(f"错误：{msg}", file=sys.stderr)
    raise SystemExit(1)


# ---------------------------------------------------------------- 本地体检


def pubspec_version() -> tuple[str, int]:
    """返回 (versionName, versionCode)，即 pubspec 的 `1.2.1+59`。"""
    text = (REPO / "app" / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*(\S+)\+(\d+)\s*$", text, re.M)
    if not m:
        die("读不出 app/pubspec.yaml 的 version")
    return m.group(1), int(m.group(2))


def aab_version(path: Path) -> int | None:
    """从 AAB 的 BundleConfig/manifest 里捞 versionCode，捞不到返回 None。

    AAB 的 AndroidManifest 是 protobuf 编码的，这里不引 bundletool，只做一次
    保守的字节扫描；拿不到就退回 pubspec 交叉验证，不阻断发布。
    """
    try:
        with zipfile.ZipFile(path) as z:
            names = z.namelist()
            if "base/manifest/AndroidManifest.xml" not in names:
                return None
            blob = z.read("base/manifest/AndroidManifest.xml")
    except (OSError, zipfile.BadZipFile):
        return None
    # protobuf 里 versionCode 以属性名字符串紧跟其整数值出现
    idx = blob.find(b"versionCode")
    if idx < 0:
        return None
    for value in re.finditer(rb"[\x18\x20\x28]([\x80-\xff]*[\x00-\x7f])", blob[idx : idx + 64]):
        raw, shift, out = value.group(1), 0, 0
        for byte in raw:
            out |= (byte & 0x7F) << shift
            shift += 7
        if 1 <= out < 1_000_000:
            return out
    return None


def parse_notes(path: Path) -> dict[str, str]:
    """解析 `=== en-US ===` 分节的发布说明文件。"""
    text = path.read_text(encoding="utf-8")
    parts = re.split(r"^===\s*([A-Za-z]{2}(?:-[A-Za-z0-9]+)?)\s*===\s*$", text, flags=re.M)
    if len(parts) < 3:
        die(f"{path.name} 里没找到 `=== 语言 ===` 分节")
    notes: dict[str, str] = {}
    for lang, body in zip(parts[1::2], parts[2::2]):
        body = body.strip()
        if body:
            notes[lang] = body
    if not notes:
        die(f"{path.name} 每一节都是空的")
    return notes


def notes_length(text: str) -> int:
    """Play 按 CRLF 计长，每个换行多算一个字符。"""
    return len(text) + text.count("\n")


def check_notes(notes: dict[str, str]) -> bool:
    ok = True
    for lang, text in sorted(notes.items()):
        n = notes_length(text)
        mark = "  " if n <= NOTES_LIMIT else "!!"
        print(f"  {mark} {lang:<8} {n:>4}/{NOTES_LIMIT}")
        if n > NOTES_LIMIT:
            ok = False
    return ok


# ---------------------------------------------------------------- Play API


def service():
    path = Path(os.environ.get("GOOGLE_APPLICATION_CREDENTIALS", CREDENTIALS))
    if not path.exists():
        die(f"服务账号凭据不存在：{path}")
    creds = service_account.Credentials.from_service_account_file(str(path), scopes=SCOPES)
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def show_tracks(svc, edit_id: str, only: str | None = None) -> None:
    resp = svc.edits().tracks().list(packageName=PACKAGE_NAME, editId=edit_id).execute()
    for track in resp.get("tracks", []):
        if only and track["track"] != only:
            continue
        print(f"  轨道 {track['track']}")
        for rel in track.get("releases", []):
            codes = ",".join(rel.get("versionCodes", []) or ["—"])
            frac = rel.get("userFraction")
            pct = f" {frac * 100:g}%" if frac is not None else ""
            langs = len(rel.get("releaseNotes", []) or [])
            print(
                f"    {rel.get('name', '?'):<18} code={codes:<6} "
                f"{rel.get('status', '?')}{pct}  发布说明 {langs} 种语言"
            )


def upload(svc, edit_id: str, path: Path) -> int:
    media = MediaFileUpload(
        str(path),
        mimetype="application/octet-stream",
        chunksize=CHUNK_SIZE,
        resumable=True,
    )
    req = svc.edits().bundles().upload(packageName=PACKAGE_NAME, editId=edit_id, media_body=media)
    total_mb = path.stat().st_size / 1024 / 1024
    response = None
    while response is None:
        # num_retries 覆盖分片级的瞬时失败；最后一片返回前 Google 要处理整包，
        # 那段等待由文件头部的 setdefaulttimeout 兜住。
        status, response = req.next_chunk(num_retries=3)
        if status:
            print(f"\r  上传中 {status.progress() * 100:5.1f}%  ({total_mb:.1f} MB)", end="")
    print(f"\r  上传完成 100.0%  ({total_mb:.1f} MB)          ")
    return int(response.get("versionCode", 0))


def deploy(args: argparse.Namespace) -> int:
    version = args.version
    aab = Path(args.file) if args.file else REPO / "dist" / f"AVA-v{version}-play.aab"
    notes_file = Path(args.notes) if args.notes else REPO / "dist" / f"release-notes-v{version}.txt"

    print(f"== play_deploy · {version} · 轨道 {args.track} · 灰度 {args.rollout:g}% ==")
    if not aab.exists():
        die(f"AAB 不存在：{aab}")
    if not notes_file.exists():
        die(f"发布说明不存在：{notes_file}")

    name, code = pubspec_version()
    if name != version:
        die(f"pubspec 是 {name}+{code}，与要发的 {version} 不一致——先 bump 或改参数")
    in_aab = aab_version(aab)
    if in_aab is not None and in_aab != code:
        die(f"AAB 里的 versionCode 是 {in_aab}，pubspec 是 {code}——这个包不是这次构建的")
    size_mb = aab.stat().st_size / 1024 / 1024
    print(f"  包    {aab.name}  {size_mb:.1f} MB  versionCode {in_aab or code}")

    notes = parse_notes(notes_file)
    print(f"  说明  {notes_file.name}")
    if not check_notes(notes):
        die(f"有语言超过 {NOTES_LIMIT} 字符——超长会让整个 commit 被 403 拒，先压缩")

    svc = service()
    edit_id = svc.edits().insert(packageName=PACKAGE_NAME, body={}).execute()["id"]
    try:
        print("-- 当前线上状态")
        show_tracks(svc, edit_id, only=args.track)

        if not args.apply:
            print("-- 演练结束，未上传任何内容。确认无误后加 --apply 重跑。")
            svc.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
            return 0

        print(f"-- 上传（{CHUNK_SIZE // 1024 // 1024} MB 分片，600 秒 socket 超时）")
        uploaded = upload(svc, edit_id, aab)
        if uploaded != code:
            die(f"Play 收到的 versionCode 是 {uploaded}，本地是 {code}")
        print(f"  Play 已接收 versionCode {uploaded}")

        release: dict = {"versionCodes": [str(uploaded)], "name": version}
        if args.rollout < 100:
            release["status"] = "inProgress"
            release["userFraction"] = args.rollout / 100.0
        else:
            release["status"] = "completed"
        release["releaseNotes"] = [{"language": k, "text": v} for k, v in notes.items()]

        svc.edits().tracks().update(
            packageName=PACKAGE_NAME,
            editId=edit_id,
            track=args.track,
            body={"releases": [release]},
        ).execute()
        print(f"-- 轨道 {args.track} 已写入 {len(notes)} 种语言的发布说明")

        svc.edits().commit(packageName=PACKAGE_NAME, editId=edit_id).execute()
        print(f"-- 已提交 edit {edit_id}")
    except HttpError as e:
        detail = e.content.decode("utf-8", "replace") if e.content else str(e)
        svc.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        die(f"Play API 拒绝：{detail}")
    except BaseException:
        svc.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
        raise

    print("-- 之后（人工，API 没有对应接口）")
    print("   1. Play Console → 发布概览 → 提交审核（开着托管发布时必须手点）")
    print("   2. 审核通过后回来核对：tool/play_deploy.py status")
    return 0


def status(args: argparse.Namespace) -> int:
    svc = service()
    edit_id = svc.edits().insert(packageName=PACKAGE_NAME, body={}).execute()["id"]
    try:
        print(f"== {PACKAGE_NAME} ==")
        show_tracks(svc, edit_id)
    finally:
        svc.edits().delete(packageName=PACKAGE_NAME, editId=edit_id).execute()
    return 0


def notes_cmd(args: argparse.Namespace) -> int:
    path = Path(args.notes) if args.notes else REPO / "dist" / f"release-notes-v{args.version}.txt"
    if not path.exists():
        die(f"发布说明不存在：{path}")
    notes = parse_notes(path)
    print(f"== {path.name} ==")
    ok = check_notes(notes)
    if args.json:
        print(json.dumps(notes, ensure_ascii=False, indent=2))
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="把 AAB 传上 Google Play（不经 MCP）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status", help="打印各轨道当前的版本与灰度")
    s.set_defaults(func=status)

    n = sub.add_parser("notes", help="只校验发布说明长度")
    n.add_argument("version")
    n.add_argument("--notes")
    n.add_argument("--json", action="store_true")
    n.set_defaults(func=notes_cmd)

    d = sub.add_parser("deploy", help="上传 AAB 并写入轨道（默认演练）")
    d.add_argument("version", help="如 1.2.1，须与 app/pubspec.yaml 一致")
    d.add_argument("--track", default="production", choices=TRACKS)
    d.add_argument("--rollout", type=float, default=100.0, help="灰度百分比，默认 100")
    d.add_argument("--file", help="AAB 路径，默认 dist/AVA-v<版本>-play.aab")
    d.add_argument("--notes", help="发布说明路径，默认 dist/release-notes-v<版本>.txt")
    d.add_argument("--apply", action="store_true", help="真正上传；不加则只做体检")
    d.set_defaults(func=deploy)

    args = ap.parse_args()
    if getattr(args, "rollout", 100.0) <= 0 or getattr(args, "rollout", 100.0) > 100:
        die("--rollout 取值须在 (0, 100]")
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
