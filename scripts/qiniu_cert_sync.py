#!/usr/bin/env python3
"""Sync a local PEM certificate (e.g. Caddy-managed Let's Encrypt) to Qiniu CDN.

Flow:
  1. Read local cert chain + private key (PEM).
  2. List existing certificates in the Qiniu account (GET /sslcert).
  3. If a cert for the domain with the same not_after already exists -> skip.
  4. Otherwise upload the new cert (POST /sslcert) and bind it to the CDN
     domain via PUT /domain/<domain>/httpsconf.

Usage:
  QINIU_ACCESS_KEY=xxx QINIU_SECRET_KEY=xxx \
    qiniu_cert_sync.py --domain static.blog.lacia.cn \
      --cert /path/static.blog.lacia.cn.crt --key /path/static.blog.lacia.cn.key \
      [--force] [--dry-run] [--delete-old]

Env:
  QINIU_ACCESS_KEY / QINIU_SECRET_KEY  Qiniu AK/SK (required)
"""
from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request

# ---------------------------------------------------------------------------
# Qiniu API endpoints
# ---------------------------------------------------------------------------
FUSION_API = "https://fusion.qiniuapi.com"   # SSL cert management (QBox auth)
CDN_API = "https://api.qiniu.com"            # CDN domain config (Qiniu timestamp auth)


def qbox_headers(auth, method: str, url: str, body: bytes | None = None, content_type: str | None = None):
    """Build headers with the classic QBox authorization (for fusion.qiniuapi.com)."""
    token = auth.token_of_request(url, body, content_type)
    headers = {
        "Authorization": f"QBox {token}",
        "Content-Type": content_type or "application/json",
    }
    return headers


def qiniu_headers(auth, method: str, url: str, body: bytes | None, content_type: str = "application/json"):
    """Build headers with the new Qiniu timestamp authorization (for api.qiniu.com)."""
    from qiniu.auth import QiniuMacAuth
    mac = QiniuMacAuth(auth.get_access_key(), auth.get_secret_key())
    x_date = _dt.datetime.now(_dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    headers = {
        "X-Qiniu-Date": x_date,
        "Content-Type": content_type,
    }
    token = mac.token_of_request(
        method=method,
        host=url.split("/")[2],
        url=url,
        qheaders=mac.qiniu_headers(headers),
        content_type=content_type,
        body=body.decode("utf-8") if isinstance(body, bytes) else body,
    )
    headers["Authorization"] = f"Qiniu {token}"
    return headers


def http_json(url: str, method: str, headers: dict, body: bytes | None = None, timeout: int = 30):
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    if not raw:
        return {}
    return json.loads(raw.decode("utf-8"))


def openssl(args: list[str]) -> str:
    proc = subprocess.run(["openssl", *args], capture_output=True, text=True, check=True)
    return proc.stdout.strip()


def local_cert_info(cert_path: str, key_path: str):
    """Return (fingerprint_sha256, not_after_epoch, not_after_text, full_chain)."""
    with open(cert_path, "r", encoding="utf-8") as fh:
        chain = fh.read().strip()
    if "-----BEGIN CERTIFICATE-----" not in chain:
        raise SystemExit(f"invalid cert file: {cert_path}")
    fp_line = openssl(["x509", "-in", cert_path, "-noout", "-fingerprint", "-sha256"])
    fingerprint = fp_line.split("=", 1)[1].replace(":", "").strip().lower()
    enddate = openssl(["x509", "-in", cert_path, "-noout", "-enddate"]).removeprefix("notAfter=")
    not_after = int(
        _dt.datetime.strptime(enddate, "%b %d %H:%M:%S %Y %Z")
        .replace(tzinfo=_dt.timezone.utc)
        .timestamp()
    )
    with open(key_path, "r", encoding="utf-8") as fh:
        key = fh.read().strip()
    return fingerprint, not_after, enddate, chain, key


def list_qiniu_certs(auth) -> list[dict]:
    certs = []
    marker = ""
    while True:
        url = f"{FUSION_API}/sslcert?marker={marker}&limit=200"
        headers = qbox_headers(auth, "GET", url)
        data = http_json(url, "GET", headers)
        certs.extend(data.get("certs", []) or [])
        marker = data.get("marker", "")
        if not marker:
            return certs


def upload_cert(auth, domain: str, chain: str, key: str, dry_run: bool) -> str:
    name = f"{domain}-{_dt.datetime.now().strftime('%Y%m%d-%H%M%S')}"
    body = json.dumps({"name": name, "pri": key, "ca": chain}).encode("utf-8")
    if dry_run:
        print(f"[dry-run] would upload cert name={name}")
        return "dry-run-cert-id"
    url = f"{FUSION_API}/sslcert"
    headers = qbox_headers(auth, "POST", url, body, "application/json")
    data = http_json(url, "POST", headers, body)
    cert_id = data.get("certID") or data.get("certid")
    if not cert_id:
        raise SystemExit(f"upload cert failed: {data}")
    print(f"uploaded cert {cert_id} ({name})")
    return cert_id


def domain_https_certid(auth, domain: str):
    """Return the certId currently bound to the CDN domain (or None)."""
    url = f"{CDN_API}/domain/{domain}"
    headers = qiniu_headers(auth, "GET", url, None)
    try:
        data = http_json(url, "GET", headers)
    except Exception:
        return None
    https = data.get("https") or {}
    for key in ("certId", "certID", "cert_id"):
        if https.get(key):
            return https.get(key)
    return None


def bind_cert(auth, domain: str, cert_id: str, dry_run: bool):
    body = json.dumps({"certId": cert_id, "forceHttps": True, "http2Enable": True}).encode("utf-8")
    url = f"{CDN_API}/domain/{domain}/httpsconf"
    if dry_run:
        print(f"[dry-run] would bind cert {cert_id} to {domain}")
        return True
    headers = qiniu_headers(auth, "PUT", url, body)
    try:
        data = http_json(url, "PUT", headers, body)
    except Exception as exc:
        print(f"bind cert failed (will retry next run): {exc}")
        return False
    if data.get("code") == 200:
        print(f"bound cert {cert_id} to https://{domain}")
        return True
    if "400910" in str(data.get("code")):  # 没有改动
        print(f"cert {cert_id} already bound to {domain}")
        return True
    print(f"bind cert failed (will retry next run): {data}")
    return False


def delete_old_certs(auth, domain: str, keep_cert_id: str, dry_run: bool):
    """Delete unused certs for the domain to avoid hitting Qiniu's cert quota."""
    for cert in list_qiniu_certs(auth):
        if cert.get("certid") == keep_cert_id:
            continue
        dnsnames = cert.get("dnsnames") or []
        if domain not in dnsnames:
            continue
        url = f"{FUSION_API}/sslcert/{cert['certid']}"
        if dry_run:
            print(f"[dry-run] would delete old cert {cert.get('certid')} {cert.get('name')}")
            continue
        try:
            data = http_json(url, "DELETE", qbox_headers(auth, "DELETE", url))
            print(f"deleted old cert {cert.get('certid')} {cert.get('name')}: {data}")
        except Exception as exc:  # noqa: BLE001 - best effort cleanup
            print(f"could not delete {cert.get('certid')}: {exc}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--domain", required=True, help="CDN domain, e.g. static.blog.lacia.cn")
    ap.add_argument("--cert", required=True, help="PEM cert chain file path")
    ap.add_argument("--key", required=True, help="PEM private key file path")
    ap.add_argument("--force", action="store_true", help="upload even if not_after is unchanged")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--delete-old", action="store_true", help="remove older Qiniu certs for this domain")
    args = ap.parse_args()

    ak = os.environ.get("QINIU_ACCESS_KEY", "")
    sk = os.environ.get("QINIU_SECRET_KEY", "")
    if not ak or not sk:
        print("QINIU_ACCESS_KEY / QINIU_SECRET_KEY must be set", file=sys.stderr)
        return 2

    from qiniu import Auth
    auth = Auth(ak, sk)

    fingerprint, not_after, enddate, chain, key = local_cert_info(args.cert, args.key)
    print(f"local cert: {args.domain} sha256={fingerprint} not_after={enddate}")

    existing_cert_id = None
    if not args.force and not args.dry_run:
        for cert in list_qiniu_certs(auth):
            dnsnames = cert.get("dnsnames") or []
            if args.domain in dnsnames and cert.get("not_after") == not_after:
                existing_cert_id = cert.get("certid")
                break

    if existing_cert_id:
        print(f"Qiniu already has this cert ({existing_cert_id})")
        if domain_https_certid(auth, args.domain) == existing_cert_id:
            print("and it is already bound to the CDN domain, nothing to do.")
            return 0
        print("cert not bound yet, binding now...")
        ok = bind_cert(auth, args.domain, existing_cert_id, args.dry_run)
        print("done")
        return 0 if ok else 1

    cert_id = upload_cert(auth, args.domain, chain, key, args.dry_run)
    ok = bind_cert(auth, args.domain, cert_id, args.dry_run)
    if args.delete_old:
        delete_old_certs(auth, args.domain, cert_id, args.dry_run)
    print("done")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
