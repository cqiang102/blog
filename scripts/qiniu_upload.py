#!/usr/bin/env python3
"""Upload Flutter web build output to Qiniu Kodo (bucket root or a prefix).

Sets correct Content-Type (notably application/wasm) and sensible Cache-Control
per file so the Qiniu CDN can accelerate static.blog.lacia.cn safely.

Env: QINIU_ACCESS_KEY, QINIU_SECRET_KEY, QINIU_BUCKET (or CLI flags).
"""
from __future__ import annotations

import argparse
import mimetypes
import os
import posixpath
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed

# ---------------------------------------------------------------------------
# Per-extension MIME map. Python's mimetypes does not know .wasm on macOS.
# ---------------------------------------------------------------------------
MIME_MAP = {
    ".wasm": "application/wasm",
    ".mjs": "text/javascript",
    ".js": "text/javascript",
    ".json": "application/json",
    ".html": "text/html",
    ".css": "text/css",
    ".svg": "image/svg+xml",
    ".woff2": "font/woff2",
    ".woff": "font/woff",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".ico": "image/x-icon",
    ".xml": "text/xml",
    ".txt": "text/plain",
    ".map": "application/json",
    ".dat": "application/octet-stream",
    ".bin": "application/octet-stream",
    ".pdf": "application/pdf",
}

def mime_for(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    if ext in MIME_MAP:
        return MIME_MAP[ext]
    guessed = mimetypes.guess_type(path)[0]
    return guessed or "application/octet-stream"


def cache_control_for(key: str) -> str:
    base = posixpath.basename(key)
    if base in NO_CACHE:
        return "no-cache"
    if base in SHORT_CACHE:
        return "public, max-age=300"
    if key.startswith(LONG_CACHE_IMMUTABLE_PREFIXES):
        return "public, max-age=31536000, immutable"
    if key.startswith(MEDIUM_CACHE_PREFIXES) or base == "favicon.png":
        return "public, max-age=86400"
    return "public, max-age=86400"


SKIP_FILES = {".last_build_id"}  # Flutter internal marker, not needed at runtime


def collect_files(src_dir: str, prefix: str):
    files = []
    for root, _dirs, names in os.walk(src_dir):
        for name in sorted(names):
            if name in SKIP_FILES:
                continue
            full = os.path.join(root, name)
            rel = os.path.relpath(full, src_dir)
            key = posixpath.join(prefix, rel) if prefix else rel
            files.append((key, full))
    return files


def upload_file(auth, bucket: str, key: str, path: str) -> tuple[bool, str]:
    from qiniu import put_file

    token = auth.upload_token(bucket, None, 3600)  # bucket scope -> allows overwrite
    mime = mime_for(path)
    ret, info = put_file(token, key, path, mime_type=mime, check_crc=False)
    if info.status_code in (200, 612):
        return True, f"{key} ({mime})"
    detail = getattr(info, "text_body", None) or getattr(info, "error", None) or ""
    return False, f"{key}: HTTP {info.status_code} {detail}"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src-dir", default=os.path.join(os.path.dirname(__file__), "..", "apps", "web_flutter", "build", "web"))
    ap.add_argument("--bucket", default=os.environ.get("QINIU_BUCKET", ""))
    ap.add_argument("--ak", default=os.environ.get("QINIU_ACCESS_KEY", ""))
    ap.add_argument("--sk", default=os.environ.get("QINIU_SECRET_KEY", ""))
    ap.add_argument("--prefix", default=os.environ.get("QINIU_PREFIX", ""), help="object key prefix, e.g. web/")
    ap.add_argument("--dry-run", action="store_true", help="list files + metadata, do not upload")
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    src = os.path.abspath(args.src_dir)
    if not os.path.isdir(src):
        print(f"src dir not found: {src}", file=sys.stderr)
        return 2
    if not args.dry_run and (not args.bucket or not args.ak or not args.sk):
        print("need --bucket/--ak/--sk or QINIU_BUCKET/QINIU_ACCESS_KEY/QINIU_SECRET_KEY", file=sys.stderr)
        return 2

    files = collect_files(src, args.prefix)
    print(f"==> {len(files)} files from {src}")
    if args.dry_run:
        for key, _ in files:
            print(f"  {key}\t{mime_for(key)}")
        return 0

    from qiniu import Auth

    auth = Auth(args.ak, args.sk)
    total = len(files)
    ok = failed = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = {pool.submit(upload_file, auth, args.bucket, k, p): k for k, p in files}
        for i, fut in enumerate(as_completed(futs), 1):
            success, msg = fut.result()
            print(f"[{i}/{total}] {'OK  ' if success else 'FAIL'} {msg}")
            ok += success
            failed += 0 if success else 1

    print(f"==> done: {ok} ok, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
