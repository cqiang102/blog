#!/usr/bin/env bash
# 上传 Flutter Web 构建产物到七牛 Kodo（默认 bucket: lacia-public）。
# 用法:
#   QINIU_ACCESS_KEY=xxx QINIU_SECRET_KEY=xxx QINIU_BUCKET=lacia-public \
#     scripts/qiniu-upload.sh [--dry-run] [--prefix=web/]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${QINIU_VENV:-$ROOT_DIR/.tools/qiniu-venv}"
PY="$VENV_DIR/bin/python"

# 默认上传到 web/<git short sha>/，与构建时 --base-href 的版本化目录保持一致
if [[ -z "${QINIU_PREFIX:-}" ]]; then
  SHA="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)"
  QINIU_PREFIX="web/$SHA/"
  echo "==> 使用版本化前缀: ${QINIU_PREFIX}（构建时请用 --base-href=https://static.blog.lacia.cn/${QINIU_PREFIX}）"
fi

if [[ ! -x "$PY" ]]; then
  echo "==> 初始化 Python venv: $VENV_DIR"
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip
  "$VENV_DIR/bin/pip" install --quiet qiniu
fi

exec "$PY" "$ROOT_DIR/scripts/qiniu_upload.py" "$@"
