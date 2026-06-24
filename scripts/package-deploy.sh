#!/usr/bin/env bash
set -euo pipefail

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
Usage: scripts/package-deploy.sh [options]

Options:
  --check       Validate local tooling, deploy files, and docker compose config.
  --skip-build  Skip Flutter/JAR builds and package existing artifacts.
  -h, --help    Show this help.

Environment overrides:
  FVM_BIN, DOCKER_BIN, MAVEN_BIN, JAVA_HOME, API_JAR, WEB_BUILD_OUTPUT,
  APP_VERSION, OUTPUT, PACKAGE_NAME

The Spring Boot JAR build passes -DskipApiDocs=true so Swagger/OpenAPI stays a local-only dependency.
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
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

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
    echo "Required file is missing: $path" >&2
    exit 1
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "$path" ]]; then
    echo "Required directory is missing: $path" >&2
    exit 1
  fi
}

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
    echo "Java 21+ is required to build the API JAR but java was not found." >&2
    exit 1
  fi

  local major
  major="$(java_major "$java_bin")"
  if [[ "$major" -lt 21 ]]; then
    echo "Java 21+ is required to build the API JAR; found Java $major at $java_bin." >&2
    exit 1
  fi
}

resolve_api_jar() {
  if [[ -n "$API_JAR" ]]; then
    require_file "$API_JAR"
    echo "$API_JAR"
    return
  fi

  if [[ ! -d "$API_DIR/target" ]]; then
    echo "No API JAR found because $API_DIR/target does not exist. Run the build first or set API_JAR=/path/to/app.jar." >&2
    exit 1
  fi

  local jars=()
  local jar
  while IFS= read -r jar; do
    jars+=("$jar")
  done < <(find "$API_DIR/target" -maxdepth 1 -type f -name '*.jar' ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort)

  if [[ "${#jars[@]}" -eq 0 ]]; then
    echo "No API JAR found under $API_DIR/target. Run the build first or set API_JAR=/path/to/app.jar." >&2
    exit 1
  fi
  if [[ "${#jars[@]}" -gt 1 ]]; then
    echo "Found multiple API JARs; set API_JAR to the one that should be deployed:" >&2
    printf '  %s\n' "${jars[@]}" >&2
    exit 1
  fi

  echo "${jars[0]}"
}

FVM_BIN="${FVM_BIN:-}"
if [[ "$RUN_BUILDS" -eq 1 || "$CHECK_ONLY" -eq 1 ]]; then
  FVM_BIN="${FVM_BIN:-$(find_command fvm /opt/homebrew/bin/fvm)}" || {
    echo "fvm is required but was not found in PATH or /opt/homebrew/bin/fvm" >&2
    exit 1
  }
fi

DOCKER_BIN="${DOCKER_BIN:-$(find_command docker /usr/local/bin/docker /Applications/Docker.app/Contents/Resources/bin/docker)}" || {
  echo "docker is required but was not found in PATH, /usr/local/bin/docker, or Docker.app" >&2
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
  echo "Maven is required to build the API JAR but was not found." >&2
  exit 1
fi

for helper_dir in /Applications/Docker.app/Contents/Resources/bin; do
  if [[ -x "$helper_dir/docker-credential-desktop" && ":$PATH:" != *":$helper_dir:"* ]]; then
    export PATH="$helper_dir:$PATH"
  fi
done

run_checks() {
  echo "==> Checking deploy inputs..."
  require_file "$DEPLOY_DIR/Dockerfile.api"
  require_file "$DEPLOY_DIR/Dockerfile.web"
  require_file "$DEPLOY_DIR/docker-compose.yml"
  require_file "$DEPLOY_DIR/nginx.conf"
  require_file "$DEPLOY_DIR/.env.example"
  require_file "$ROOT_DIR/infra/postgres/init/01-extensions.sql"

  echo "==> Checking local tools..."
  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    "$FVM_BIN" --version >/dev/null
    "$MAVEN_BIN" -version >/dev/null
  fi
  "$DOCKER_BIN" compose version >/dev/null

  echo "==> Checking docker compose config..."
  (
    # docker compose gives shell variables precedence over --env-file values.
    # Unset keys from the example file so empty local env vars do not shadow it.
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
  echo "==> Deploy script check passed."
  exit 0
fi

if [[ "$RUN_BUILDS" -eq 1 ]]; then
  echo "==> [1/4] Building Flutter Web..."
  cd "$WEB_DIR"
  "$FVM_BIN" flutter pub get
  "$FVM_BIN" flutter build web --release --tree-shake-icons --dart-define=API_BASE_URL=/api/v1

  echo "==> [2/4] Building Spring Boot JAR..."
  cd "$API_DIR"
  "$MAVEN_BIN" clean package -DskipTests -DskipApiDocs=true -B
else
  echo "==> [1/4] Skipping Flutter Web build..."
  echo "==> [2/4] Skipping Spring Boot JAR build..."
fi

echo "==> [3/4] Assembling deploy directory..."
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
  "$STAGING_DIR/postgres/init" \
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
cp "$ROOT_DIR/infra/postgres/init/01-extensions.sql" "$STAGING_DIR/postgres/init/"

echo "==> [4/4] Packaging tar.gz..."
mkdir -p "$(dirname "$OUTPUT")"
tar czf "$OUTPUT" -C "$STAGING_ROOT" "$PACKAGE_NAME"

echo ""
echo "==> Done! Output: $OUTPUT"
echo "    Upload to server and run:"
echo "    tar xzf $(basename "$OUTPUT") && cd $PACKAGE_NAME"
echo "    cp .env.example .env && vim .env"
echo "    docker compose up -d --build"
