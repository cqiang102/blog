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
API_JAR="${API_JAR:-}"
WEB_BUILD_OUTPUT="${WEB_BUILD_OUTPUT:-$WEB_DIR/build/web}"
RUN_BUILDS=1
CHECK_ONLY=0

usage() {
  cat <<USAGE
用法：scripts/package-deploy.sh [选项]

选项：
  --check       只检查本地工具、部署文件和 Docker Compose 配置。
  --skip-build  跳过 Flutter/JAR 构建，直接打包已有产物。
  -h, --help    显示帮助。

可覆盖的环境变量：
  FVM_BIN, DOCKER_BIN, MAVEN_BIN, JAVA_HOME, API_JAR, WEB_BUILD_OUTPUT,
  APP_VERSION, OUTPUT, PACKAGE_NAME

说明：
  Spring Boot JAR 构建会传入 -DskipApiDocs=true，生产部署包不包含 Swagger/OpenAPI 依赖。
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

# 提取 Java 主版本号，兼容 1.8 和 21.0.x 两类版本输出。
java_major() {
  local java_bin="$1"
  local version_line
  version_line="$("$java_bin" -version 2>&1 | head -n 1)"
  if [[ "$version_line" =~ \"1\.([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$version_line" =~ \"([0-9]+)(\.|-|\") ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "0"
  fi
}

# 构建后端 JAR 必须使用 Java 21+；macOS 上优先用 /usr/libexec/java_home 自动切换。
ensure_java_21() {
  local java_bin="${JAVA_HOME:+$JAVA_HOME/bin/java}"
  if [[ -n "$java_bin" && -x "$java_bin" ]]; then
    local configured_major
    configured_major="$(java_major "$java_bin")"
    if [[ "$configured_major" -ge 21 ]]; then
      return
    fi
  fi

  if [[ "$(uname -s)" == "Darwin" && -x /usr/libexec/java_home ]]; then
    local java_home
    java_home="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
    if [[ -n "$java_home" ]]; then
      export JAVA_HOME="$java_home"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
  fi

  java_bin="${JAVA_HOME:+$JAVA_HOME/bin/java}"
  if [[ -z "$java_bin" || ! -x "$java_bin" ]]; then
    java_bin="$(find_command java || true)"
  fi

  if [[ -z "$java_bin" || ! -x "$java_bin" ]]; then
    echo "构建 API JAR 需要 Java 21+，但未找到 java 命令。" >&2
    exit 1
  fi

  local major
  major="$(java_major "$java_bin")"
  if [[ "$major" -lt 21 ]]; then
    echo "构建 API JAR 需要 Java 21+；当前为 Java $major，路径：$java_bin。" >&2
    exit 1
  fi
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

MAVEN_BIN="${MAVEN_BIN:-}"
if [[ "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ]]; then
  ensure_java_21
fi
if [[ ( "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ) && -z "$MAVEN_BIN" ]]; then
  MAVEN_BIN="$(find_command mvn /opt/homebrew/bin/mvn /usr/local/bin/mvn "$HOME/wubihuan/apache-maven-3.8.8/bin/mvn" "$HOME/wubihuan/apache-maven-3.6.3/bin/mvn" || true)"
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
  require_file "$DEPLOY_DIR/Dockerfile.api"
  require_file "$DEPLOY_DIR/Dockerfile.web"
  require_file "$DEPLOY_DIR/docker-compose.yml"
  require_file "$DEPLOY_DIR/nginx.conf"
  require_file "$DEPLOY_DIR/.env.example"

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
  )
}

run_checks

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo "==> 部署脚本检查通过。"
  exit 0
fi

if [[ "$RUN_BUILDS" -eq 1 ]]; then
  echo "==> [1/4] 构建 Flutter Web..."
  cd "$WEB_DIR"
  "$FVM_BIN" flutter pub get
  "$FVM_BIN" flutter build web --release --tree-shake-icons --dart-define=API_BASE_URL=/api/v1

  echo "==> [2/4] 构建 Spring Boot JAR..."
  cd "$API_DIR"
  "$MAVEN_BIN" clean package -DskipTests -DskipApiDocs=true -B
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
  "$STAGING_DIR/.data/minio"
cp "$DEPLOY_DIR/Dockerfile.api" "$STAGING_DIR/"
cp "$DEPLOY_DIR/Dockerfile.web" "$STAGING_DIR/"
cp "$DEPLOY_DIR/docker-compose.yml" "$STAGING_DIR/"
cp "$DEPLOY_DIR/nginx.conf" "$STAGING_DIR/"
cp "$DEPLOY_DIR/.env.example" "$STAGING_DIR/"
cp "$API_JAR_PATH" "$STAGING_DIR/blog-api.jar"
cp -R "$WEB_BUILD_OUTPUT/." "$STAGING_DIR/web/"

echo "==> [4/4] 打包 tar.gz..."
mkdir -p "$(dirname "$OUTPUT")"
tar czf "$OUTPUT" -C "$STAGING_ROOT" "$PACKAGE_NAME"

echo ""
echo "==> 完成！产物：$OUTPUT"
echo "    上传到服务器后执行："
echo "    tar xzf $(basename "$OUTPUT") && cd $PACKAGE_NAME"
echo "    cp .env.example .env && vim .env"
echo "    docker compose up -d --build"
