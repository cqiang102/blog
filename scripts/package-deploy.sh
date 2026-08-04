#!/usr/bin/env bash
set -euo pipefail

# 生产部署包打包入口：构建前后端产物，并组装可直接 docker compose 启动的压缩包。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"
WEB_DIR="$ROOT_DIR/apps/web_flutter"
DEPLOY_DIR="$ROOT_DIR/deploy"
APP_VERSION="${APP_VERSION:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"
OUTPUT="${OUTPUT:-$ROOT_DIR/blog-mimo-$APP_VERSION.tar.gz}"
PACKAGE_NAME="${PACKAGE_NAME:-blog-deploy}"
CADDY_IMAGE="${CADDY_IMAGE:-caddy:2.11.4-alpine}"
API_JAR="${API_JAR:-}"
WEB_BUILD_OUTPUT="${WEB_BUILD_OUTPUT:-$WEB_DIR/build/web}"
WEB_BASE_HREF="${WEB_BASE_HREF:-/}"
WEB_API_BASE_URL="${WEB_API_BASE_URL:-/api/v1}"
RUN_BUILDS=1
CHECK_ONLY=0
INCLUDE_DEPLOY_ENV=0

# shellcheck source=scripts/lib/java-toolchain.sh
source "$ROOT_DIR/scripts/lib/java-toolchain.sh"

usage() {
  cat <<USAGE
用法：scripts/package-deploy.sh [选项]

选项：
  --check       只检查本地工具、部署文件和 Docker Compose 配置。
  --skip-build  跳过 Flutter/JAR 构建，直接打包已有产物。
  --include-env 显式把 deploy/.env 放入部署包（包含明文凭据，谨慎使用）。
  -h, --help    显示帮助。

可覆盖的环境变量：
  FVM_BIN, DOCKER_BIN, MAVEN_BIN, PYTHON_BIN, JAVA_HOME, JAVA_HOME_OVERRIDE, CADDY_IMAGE, API_JAR,
  WEB_BUILD_OUTPUT, WEB_BASE_HREF, WEB_API_BASE_URL, APP_VERSION, OUTPUT, PACKAGE_NAME

说明：
  Spring Boot JAR 构建会传入 -DskipApiDocs=true，生产部署包不包含 Swagger/OpenAPI 依赖。
  默认构建会先执行 Dart 格式检查、Flutter 分析/测试和 Maven verify；--skip-build 仅用于打包已验证的现有产物。
  默认不打包 deploy/.env；只有传入 --include-env 时才会把明文生产配置放入部署包。
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      ;;
    --skip-build)
      RUN_BUILDS=0
      ;;
    --include-env)
      INCLUDE_DEPLOY_ENV=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "未知选项：$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# 在 PATH 和常见安装位置中查找命令，方便本机环境路径不完全一致时复用脚本。
find_command() {
  local name="$1"
  shift
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return
  fi
  local candidate
  for candidate in "$@"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  return 1
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "缺少必要文件：$path" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "缺少必要目录：$path" >&2
    exit 1
  fi
}

# 构建后端 JAR 必须使用 Java 25+。
ensure_java_25() {
  local resolved_java_home
  if ! resolved_java_home="$(resolve_java_25_home "${JAVA_HOME_OVERRIDE:-}" "${JAVA_HOME:-}")"; then
    echo "构建 API JAR 需要 Java 25+。请设置 JAVA_HOME/JAVA_HOME_OVERRIDE，或把 Java 25 加入 PATH。" >&2
    exit 1
  fi
  export JAVA_HOME="$resolved_java_home"
  export PATH="$JAVA_HOME/bin:$PATH"
}

# 允许外部通过 API_JAR 指定已有 JAR；否则从 apps/api/target 中解析唯一可部署 JAR。
resolve_api_jar() {
  if [[ -n "$API_JAR" ]]; then
    require_file "$API_JAR"
    echo "$API_JAR"
    return
  fi

  if [[ ! -d "$API_DIR/target" ]]; then
    echo "未找到 API JAR，因为 $API_DIR/target 不存在。请先构建，或设置 API_JAR=/path/to/app.jar。" >&2
    exit 1
  fi

  local jars=()
  local jar
  while IFS= read -r jar; do
    jars+=("$jar")
  done < <(find "$API_DIR/target" -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort)

  if [[ "${#jars[@]}" -eq 0 ]]; then
    echo "未在 $API_DIR/target 下找到 API JAR。请先构建，或设置 API_JAR=/path/to/app.jar。" >&2
    exit 1
  fi
  if [[ "${#jars[@]}" -gt 1 ]]; then
    echo "发现多个 API JAR，请通过 API_JAR 指定要部署的文件：" >&2
    printf '  %s\n' "${jars[@]}" >&2
    exit 1
  fi

  echo "${jars[0]}"
}

FVM_BIN="${FVM_BIN:-}"
# --check 和正常构建都需要 Flutter 工具；--skip-build 只打包已有产物。
if [[ "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ]]; then
  FVM_BIN="${FVM_BIN:-$(find_command fvm /opt/homebrew/bin/fvm)}" || {
    echo "需要 fvm，但未在 PATH 或 /opt/homebrew/bin/fvm 中找到。" >&2
    exit 1
  }
fi

DOCKER_BIN="${DOCKER_BIN:-$(find_command docker /usr/local/bin/docker /Applications/Docker.app/Contents/Resources/bin/docker)}" || {
  echo "需要 docker，但未在 PATH、/usr/local/bin/docker 或 Docker.app 中找到。" >&2
  exit 1
}

PYTHON_BIN="${PYTHON_BIN:-$(find_command python3 /usr/bin/python3 /opt/homebrew/bin/python3)}" || {
  echo "部署配置检查需要 python3，但未在 PATH 或常见安装位置中找到。" >&2
  exit 1
}

MAVEN_BIN="${MAVEN_BIN:-}"
if [[ "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ]]; then
  ensure_java_25
fi
if [[ ( "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ) && -z "$MAVEN_BIN" ]]; then
  if [[ -x "$API_DIR/mvnw" ]]; then
    MAVEN_BIN="$API_DIR/mvnw"
  else
    MAVEN_BIN="$(find_command mvn /opt/homebrew/bin/mvn /usr/local/bin/mvn "$HOME/wubihuan/apache-maven-3.8.8/bin/mvn" "$HOME/wubihuan/apache-maven-3.6.3/bin/mvn" || true)"
  fi
fi
if [[ ( "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ) && -z "$MAVEN_BIN" ]]; then
  echo "构建 API JAR 需要 Maven，但未找到 Maven。" >&2
  exit 1
fi

# Docker Desktop 的凭据助手有时不在 PATH 中，补进去以便 compose 能拉取镜像。
for helper_dir in /Applications/Docker.app/Contents/Resources/bin; do
  if [[ -x "$helper_dir/docker-credential-desktop" && ":$PATH:" != *":$helper_dir:"* ]]; then
    export PATH="$helper_dir:$PATH"
  fi
done

run_checks() {
  echo "==> 检查部署输入文件..."
  require_file "$DEPLOY_DIR/docker-compose.yml"
  require_file "$DEPLOY_DIR/Caddyfile"
  require_file "$DEPLOY_DIR/Caddyfile.host.example"
  require_file "$DEPLOY_DIR/.env.example"
  require_file "$ROOT_DIR/docs/deployment.md"
  if [[ "$INCLUDE_DEPLOY_ENV" == "1" && ! -f "$DEPLOY_DIR/.env" ]]; then
    echo "已指定 --include-env，但 $DEPLOY_DIR/.env 不存在。" >&2
    exit 1
  fi

  echo "==> 检查本地工具..."
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    "$FVM_BIN" --version >/dev/null
    "$MAVEN_BIN" -version >/dev/null
  fi
  "$DOCKER_BIN" compose version >/dev/null

  echo "==> 检查 Docker Compose 配置..."
  (
    # Docker Compose 会让 shell 环境变量优先于 --env-file。
    # 这里先清掉示例 env 中的键，避免本机空变量覆盖示例值。
    while IFS='=' read -r key _; do
      if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        unset "$key"
      fi
    done <"$DEPLOY_DIR/.env.example"
    "$DOCKER_BIN" compose \
      --env-file "$DEPLOY_DIR/.env.example" \
      -f "$DEPLOY_DIR/docker-compose.yml" \
      config >/dev/null
    "$DOCKER_BIN" compose \
      --env-file "$DEPLOY_DIR/.env.example" \
      -f "$DEPLOY_DIR/docker-compose.yml" \
      config --format json \
      | "$PYTHON_BIN" -c '
import json
import sys

services = json.load(sys.stdin)["services"]
if "web" in services:
    raise SystemExit("default Compose config must not enable the bundled web Caddy")

expected = {"api": ("127.0.0.1", "18080"), "minio": ("127.0.0.1", "19000")}
for service_name, (host_ip, published) in expected.items():
    ports = services[service_name].get("ports", [])
    if not any(port.get("host_ip") == host_ip and str(port.get("published")) == published for port in ports):
        raise SystemExit(
            f"{service_name} must publish only {host_ip}:{published} in the example host-Caddy config"
        )
'
    "$DOCKER_BIN" compose \
      --profile bundled-caddy \
      --env-file "$DEPLOY_DIR/.env.example" \
      -f "$DEPLOY_DIR/docker-compose.yml" \
      config >/dev/null
    "$DOCKER_BIN" compose \
      --profile bundled-caddy \
      --env-file "$DEPLOY_DIR/.env.example" \
      -f "$DEPLOY_DIR/docker-compose.yml" \
      config --services \
      | grep -qx web
  )

  echo "==> 检查 Caddy 配置..."
  "$DOCKER_BIN" run --rm \
    -e FRONTEND_BASE_URL=https://example.com \
    -v "$DEPLOY_DIR/Caddyfile:/etc/caddy/Caddyfile:ro" \
    "$CADDY_IMAGE" \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
  "$DOCKER_BIN" run --rm \
    -v "$DEPLOY_DIR/Caddyfile.host.example:/etc/caddy/Caddyfile:ro" \
    "$CADDY_IMAGE" \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
}

run_checks

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "==> 部署脚本检查通过。"
  exit 0
fi

if [[ "$RUN_BUILDS" -eq 1 ]]; then
  echo "==> [1/4] 验证并构建 Flutter Web..."
  cd "$WEB_DIR"
  "$FVM_BIN" flutter pub get
  "$FVM_BIN" dart format --output=none --set-exit-if-changed lib test
  "$FVM_BIN" flutter analyze
  "$FVM_BIN" flutter test
  "$FVM_BIN" flutter build web --release --wasm --tree-shake-icons --base-href="$WEB_BASE_HREF" --dart-define=API_BASE_URL="$WEB_API_BASE_URL"
  # CanvasKit/SkWasm 改为本地加载，避免 gstatic CDN（国内访问慢）
  bash "$ROOT_DIR/apps/web_flutter/tool/patch_flutter_bootstrap.sh" "$WEB_BUILD_OUTPUT"

  echo "==> [2/4] 验证并构建 Spring Boot JAR..."
  cd "$API_DIR"
  "$MAVEN_BIN" clean verify -DskipApiDocs=true -B
else
  echo "==> [1/4] 跳过 Flutter Web 构建..."
  echo "==> [2/4] 跳过 Spring Boot JAR 构建..."
fi

echo "==> [3/4] 组装部署目录..."
API_JAR_PATH="$(resolve_api_jar)"
require_dir "$WEB_BUILD_OUTPUT"

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/blog-deploy.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_ROOT"
}
trap cleanup EXIT

STAGING_DIR="$STAGING_ROOT/$PACKAGE_NAME"
mkdir -p \
  "$STAGING_DIR/web" \
  "$STAGING_DIR/.data/postgres" \
  "$STAGING_DIR/.data/redis" \
  "$STAGING_DIR/.data/minio" \
  "$STAGING_DIR/.data/caddy/data" \
  "$STAGING_DIR/.data/caddy/config"
cp "$DEPLOY_DIR/docker-compose.yml" "$STAGING_DIR/"
cp "$DEPLOY_DIR/Caddyfile" "$STAGING_DIR/"
cp "$DEPLOY_DIR/Caddyfile.host.example" "$STAGING_DIR/"
cp "$DEPLOY_DIR/.env.example" "$STAGING_DIR/"
cp "$ROOT_DIR/docs/deployment.md" "$STAGING_DIR/DEPLOYMENT.md"
if [[ "$INCLUDE_DEPLOY_ENV" == "1" ]]; then
  cp "$DEPLOY_DIR/.env" "$STAGING_DIR/.env"
fi
cp "$API_JAR_PATH" "$STAGING_DIR/blog-api.jar"
cp -R "$WEB_BUILD_OUTPUT/." "$STAGING_DIR/web/"

echo "==> [4/4] 打包 tar.gz..."
mkdir -p "$(dirname "$OUTPUT")"
tar czf "$OUTPUT" -C "$STAGING_ROOT" "$PACKAGE_NAME"

echo ""
echo "==> 完成！产物：$OUTPUT"
echo "    上传前请先阅读包内 DEPLOYMENT.md，并核验服务器 SSH 主机指纹。"
if [[ "$INCLUDE_DEPLOY_ENV" == "1" ]]; then
  echo "    已包含 deploy/.env；请限制文件权限，并迁移为服务器 shared/.env。"
else
  echo "    默认未包含 .env；服务器使用 /srv/blog-mimo/shared/.env。"
fi
echo "    # 服务器已有 Caddy（推荐）："
echo "    按 DEPLOYMENT.md 版本化解压并执行默认 docker compose up。"
echo "    然后合并 Caddyfile.host.example 并平滑 reload。"
echo "    # 独占 80/443 的全容器模式："
echo "    docker compose --profile bundled-caddy up -d --build"
