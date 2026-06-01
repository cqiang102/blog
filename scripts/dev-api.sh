#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"
MAVEN_BIN="${MAVEN_BIN:-/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn}"
COMMAND="${1:-run}"
PROFILES="${2:-local}"
LOG_FILE="${LOG_FILE:-$API_DIR/target/dev-api.log}"

if [[ "$COMMAND" == "local"* || "$COMMAND" == *","* ]]; then
  PROFILES="$COMMAND"
  COMMAND="run"
fi

if [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
  cat <<'USAGE'
Usage:
  scripts/dev-api.sh [command] [profiles]

Examples:
  scripts/dev-api.sh                 # start Docker dependencies and run local profile
  scripts/dev-api.sh run local,nodb  # run API without PostgreSQL/Flyway/pgvector
  scripts/dev-api.sh local,nodb      # shortcut for the previous command
  scripts/dev-api.sh status          # show Docker service status
  scripts/dev-api.sh logs            # show recent Docker logs
  scripts/dev-api.sh app-log         # show recent backend app log
  scripts/dev-api.sh reset-db        # delete local Docker volumes and recreate services
  scripts/dev-api.sh doctor          # print Java/Maven/Docker/PostgreSQL diagnostics
  scripts/dev-api.sh test            # run backend tests with Maven
  SKIP_DOCKER=1 scripts/dev-api.sh run local

Environment:
  MAVEN_BIN    Override Maven binary path.
  SKIP_DOCKER  Set to 1 to skip docker compose startup.
  JAVA_HOME_OVERRIDE  Override the auto-detected Java 21 home.
  LOG_FILE  Override backend run log path.
USAGE
  exit 0
fi

if [[ ! -x "$MAVEN_BIN" ]]; then
  echo "Maven not found or not executable: $MAVEN_BIN" >&2
  exit 1
fi

export JAVA_HOME="${JAVA_HOME_OVERRIDE:-$(/usr/libexec/java_home -v 21)}"
export PATH="$JAVA_HOME/bin:$(dirname "$MAVEN_BIN"):$PATH"
COMPOSE=(docker compose -f "$ROOT_DIR/infra/docker-compose.yml")

print_section() {
  printf '\n== %s ==\n' "$1"
}

if [[ -f "$API_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$API_DIR/.env"
  set +a
fi

case "$COMMAND" in
  status)
    "${COMPOSE[@]}" ps
    exit 0
    ;;
  logs)
    "${COMPOSE[@]}" logs --tail=120
    exit 0
    ;;
  app-log)
    if [[ -f "$LOG_FILE" ]]; then
      tail -n 160 "$LOG_FILE"
    else
      echo "Backend app log does not exist yet: $LOG_FILE" >&2
      exit 1
    fi
    exit 0
    ;;
  doctor)
    print_section "Paths"
    echo "ROOT_DIR=$ROOT_DIR"
    echo "API_DIR=$API_DIR"
    echo "JAVA_HOME=$JAVA_HOME"
    echo "MAVEN_BIN=$MAVEN_BIN"

    print_section "Java"
    java -version

    print_section "Maven"
    "$MAVEN_BIN" --version

    print_section "Docker"
    if docker info >/dev/null 2>&1; then
      docker info --format 'Server Version: {{.ServerVersion}}'
      "${COMPOSE[@]}" ps
    else
      echo "Docker daemon is not reachable. Start Docker Desktop, then retry."
    fi

    print_section "PostgreSQL"
    if "${COMPOSE[@]}" exec -T postgres pg_isready -U blog -d blog >/dev/null 2>&1; then
      echo "PostgreSQL is ready."
    else
      echo "PostgreSQL is not ready or the postgres container is not running."
    fi

    print_section "Ports"
    for port in 8080 5432 6379 9000 9001; do
      if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Port $port is in use:"
        lsof -nP -iTCP:"$port" -sTCP:LISTEN
      else
        echo "Port $port is free."
      fi
    done
    exit 0
    ;;
  reset-db)
    "${COMPOSE[@]}" down -v
    "${COMPOSE[@]}" up -d
    exit 0
    ;;
  test)
    cd "$API_DIR"
    exec "$MAVEN_BIN" test
    ;;
  run)
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Run 'scripts/dev-api.sh --help' for usage." >&2
    exit 1
    ;;
esac

if [[ "${SKIP_DOCKER:-0}" != "1" && "$PROFILES" != *"nodb"* ]]; then
  "${COMPOSE[@]}" up -d
  echo "Waiting for PostgreSQL to accept connections..."
  for attempt in {1..30}; do
    if "${COMPOSE[@]}" exec -T postgres pg_isready -U blog -d blog >/dev/null 2>&1; then
      break
    fi
    if [[ "$attempt" == "30" ]]; then
      echo "PostgreSQL did not become ready in time. Run 'docker compose -f infra/docker-compose.yml logs postgres' for details." >&2
      exit 1
    fi
    sleep 1
  done
fi

cd "$API_DIR"
mkdir -p "$(dirname "$LOG_FILE")"
echo "Writing backend log to $LOG_FILE"
"$MAVEN_BIN" spring-boot:run -Dspring-boot.run.profiles="$PROFILES" 2>&1 | tee "$LOG_FILE"
exit "${PIPESTATUS[0]}"
