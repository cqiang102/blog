#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"
WEB_DIR="$ROOT_DIR/apps/web_flutter"
DEPLOY_DIR="$ROOT_DIR/deploy"
OUTPUT="$ROOT_DIR/blog-deploy.tar.gz"

echo "==> [1/4] Building Flutter Web..."
cd "$WEB_DIR"
fvm flutter pub get
fvm flutter build web --release --tree-shake-icons --dart-define=API_BASE_URL=/api/v1

echo "==> [2/4] Building Native Image in Docker (Linux)..."
cd "$API_DIR"
docker run --rm \
  -v "$(pwd)":/app -w /app \
  -v "$HOME/.m2":/root/.m2 \
  ghcr.io/graalvm/native-image-community:21 \
  mvn native:compile -DskipTests -B

echo "==> [3/4] Assembling deploy directory..."
# 清理旧的产物（保留 Dockerfile 等源文件）
rm -f "$DEPLOY_DIR/blog-api"
rm -rf "$DEPLOY_DIR/web"
rm -rf "$DEPLOY_DIR/postgres"

# 复制产物
cp "$API_DIR/target/blog-api" "$DEPLOY_DIR/"
mkdir -p "$DEPLOY_DIR/web" "$DEPLOY_DIR/postgres/init"
cp -r "$WEB_DIR/build/web/"* "$DEPLOY_DIR/web/"
cp "$ROOT_DIR/infra/postgres/init/01-extensions.sql" "$DEPLOY_DIR/postgres/init/"

echo "==> [4/4] Packaging tar.gz..."
cd "$DEPLOY_DIR"
tar czf "$OUTPUT" \
  Dockerfile.api \
  Dockerfile.web \
  docker-compose.yml \
  nginx.conf \
  .env.example \
  blog-api \
  web \
  postgres

# 清理临时产物
rm -f "$DEPLOY_DIR/blog-api"
rm -rf "$DEPLOY_DIR/web"
rm -rf "$DEPLOY_DIR/postgres"

echo ""
echo "==> Done! Output: $OUTPUT"
echo "    Upload to server and run:"
echo "    tar xzf blog-deploy.tar.gz && cd blog-deploy"
echo "    cp .env.example .env && vim .env"
echo "    docker compose up -d"
