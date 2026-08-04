#!/usr/bin/env bash
# 将 Caddy 管理的证书同步到七牛云 CDN（供 static.blog.lacia.cn 使用）。
# 由 systemd timer 定期调用；只有证书更新时才会真正调用七牛 API。
set -euo pipefail

BASE_DIR="/usr/local/docker/qiniu-cert-sync"
VENV_DIR="$BASE_DIR/venv"
PY="$VENV_DIR/bin/python"

DOMAIN="${QINIU_SYNC_DOMAIN:-static.blog.lacia.cn}"
CERT_FILE="${QINIU_SYNC_CERT:-/usr/local/docker/nginx-gateway/data/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN/$DOMAIN.crt}"
KEY_FILE="${QINIU_SYNC_KEY:-/usr/local/docker/nginx-gateway/data/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN/$DOMAIN.key}"

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
  echo "证书文件不存在（可能 Caddy 尚未签发）: $CERT_FILE / $KEY_FILE"
  exit 0
fi

if [[ ! -x "$PY" ]]; then
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet qiniu
fi

exec "$PY" "$BASE_DIR/qiniu_cert_sync.py" \
  --domain "$DOMAIN" \
  --cert "$CERT_FILE" \
  --key "$KEY_FILE" \
  --delete-old
