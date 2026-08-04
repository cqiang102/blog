#!/usr/bin/env bash
# 将 flutter_bootstrap.js 的 CanvasKit/SkWasm 加载地址改为本地 canvaskit/，
# 避免从 www.gstatic.com CDN 加载（国内访问慢且不可控）。
# 用法: patch_flutter_bootstrap.sh [build/web 目录，默认 build/web]
set -euo pipefail

WEB_DIR="${1:-build/web}"
F="$WEB_DIR/flutter_bootstrap.js"

if [ ! -f "$F" ]; then
  echo "flutter_bootstrap.js not found: $F" >&2
  exit 1
fi

if grep -q 'canvasKitBaseUrl: "canvaskit/"' "$F"; then
  echo "已打过补丁，跳过: $F"
  exit 0
fi

python3 - "$F" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read().rstrip()
assert s.endswith('});'), 'unexpected bootstrap tail'
s = s[:-3] + ''',
  config: {
    canvasKitBaseUrl: "canvaskit/"
  }
});'''
open(path, 'w').write(s)
print('patched:', path)
PY
