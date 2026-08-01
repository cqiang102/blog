#!/usr/bin/env bash
set -euo pipefail

# 本地后端启动入口：读取 apps/api/.env，按需启动 infra，再运行 Spring Boot。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"
MAVEN_BIN="${MAVEN_BIN:-$API_DIR/mvnw}"
COMMAND="${1:-run}"
PROFILES="${2:-dev}"
LOG_FILE="${LOG_FILE:-$API_DIR/target/dev-api.log}"
LOCAL_ENV_FILE="$API_DIR/.env"
RUN_TESTS=0

# shellcheck source=scripts/lib/java-toolchain.sh
source "$ROOT_DIR/scripts/lib/java-toolchain.sh"

# 支持 `scripts/dev-api.sh dev` 这种快捷写法，等价于 `run dev`。
if [[ "$COMMAND" == "dev"* || "$COMMAND" == *","* ]]; then
  PROFILES="$COMMAND"
  COMMAND="run"
fi

if [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
  cat <<'USAGE'
用法：
  scripts/dev-api.sh [命令] [Spring 配置环境]

示例：
  scripts/dev-api.sh                 # 启动本地依赖并使用 dev 配置环境运行后端
  scripts/dev-api.sh run dev         # 使用 dev 配置环境运行后端
  scripts/dev-api.sh dev             # 上一条命令的快捷写法
  scripts/dev-api.sh app-log         # 查看最近的后端运行日志
  scripts/dev-api.sh test            # 使用 Maven 运行后端完整验证（需要 Docker/Testcontainers）
  SKIP_INFRA=1 scripts/dev-api.sh run dev

环境变量：
  MAVEN_BIN           覆盖 Maven 可执行文件路径。
  SKIP_INFRA          设为 1 时跳过 scripts/infra.sh up。
  JAVA_HOME_OVERRIDE  覆盖自动探测到的 Java 25 路径。
  LOG_FILE            覆盖后端运行日志路径。
  本地配置会从 apps/api/.env 读取。
USAGE
  exit 0
fi

# 将 apps/api/.env 暴露给 Spring Boot；本地依赖的 env 文件由 scripts/infra.sh 传给 Compose。
if [[ -f "$LOCAL_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$LOCAL_ENV_FILE"
  set +a
fi

case "$COMMAND" in
  app-log)
    if [[ -f "$LOG_FILE" ]]; then
      tail -n 160 "$LOG_FILE"
    else
      echo "后端运行日志还不存在：$LOG_FILE" >&2
      exit 1
    fi
    exit 0
    ;;
  test)
    RUN_TESTS=1
    ;;
  run)
    ;;
  *)
    echo "未知命令：$COMMAND" >&2
    echo "运行 'scripts/dev-api.sh --help' 查看用法。" >&2
    exit 1
    ;;
esac

if [[ ! -x "$MAVEN_BIN" ]]; then
  MAVEN_BIN="$(command -v mvn || true)"
  if [[ ! -x "$MAVEN_BIN" ]]; then
    echo "未找到 Maven Wrapper 或 Maven。请确认 apps/api/mvnw 可执行，或设置 MAVEN_BIN=/path/to/mvn。" >&2
    exit 1
  fi
fi

# 统一使用 Java 25+，避免本机默认 JDK 版本影响 Spring Boot 启动。
if ! JAVA_HOME="$(resolve_java_25_home "${JAVA_HOME_OVERRIDE:-}" "${JAVA_HOME:-}")"; then
  echo "需要 Java 25+。请设置 JAVA_HOME/JAVA_HOME_OVERRIDE，或把 Java 25 加入 PATH。" >&2
  exit 1
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$(dirname "$MAVEN_BIN"):$PATH"

# test 命令不启动常驻基础设施，但完整验证会通过 Testcontainers 使用 Docker。
if [[ "$RUN_TESTS" == "1" ]]; then
  cd "$API_DIR"
  exec "$MAVEN_BIN" clean verify -DskipApiDocs=true
fi

# 默认先拉起本地依赖；依赖已启动时可通过 SKIP_INFRA=1 跳过。
if [[ "${SKIP_INFRA:-0}" != "1" ]]; then
  "$ROOT_DIR/scripts/infra.sh" up
  "$ROOT_DIR/scripts/infra.sh" wait
fi

cd "$API_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
echo "后端运行日志写入：$LOG_FILE"
"$MAVEN_BIN" spring-boot:run -Dspring-boot.run.profiles="$PROFILES" 2>&1 | tee "$LOG_FILE"
exit "${PIPESTATUS[0]}"
