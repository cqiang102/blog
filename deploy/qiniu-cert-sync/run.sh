#!/usr/bin/env bash
# 将 Caddy 管理的证书同步到七牛云 CDN（static.blog.lacia.cn / file.lacia.cn）。
# 由 systemd timer 定期调用；只有证书更新时才会真正调用七牛 API。
set -euo pipefail

BASE_DIR="/usr/local/docker/qiniu-cert-sync"
VENV_DIR="$BASE_DIR/venv"
PY="$VENV_DIR/bin/python"

if [[ -f "$BASE_DIR/env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$BASE_DIR/env"
  set +a
fi

CERTS_ROOT="/usr/local/docker/nginx-gateway/data/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory"
DOMAINS=(static.blog.lacia.cn file.lacia.cn)

if [[ ! -x "$PY" || ! -x "$VENV_DIR/bin/pip" ]]; then
  python3 -m venv --clear "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet qiniu
fi

for domain in "${DOMAINS[@]}"; do
  cert="$CERTS_ROOT/$domain/$domain.crt"
  key="$CERTS_ROOT/$domain/$domain.key"
  if [[ ! -f "$cert" || ! -f "$key" ]]; then
    echo "证书文件不存在（可能 Caddy 尚未签发）: $cert / $key"
    continue
  fi
  echo "==> sync $domain"
  "$PY" "$BASE_DIR/qiniu_cert_sync.py" \
    --domain "$domain" \
    --cert "$cert" \
    --key "$key" \
    --delete-old
done
