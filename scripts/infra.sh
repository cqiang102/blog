#!/usr/bin/env bash
set -euo pipefail

# 本地基础设施管理入口：统一管理 PostgreSQL、Redis、MinIO。
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/apps/api/.env}"
DATA_DIR="$ROOT_DIR/deploy/.data"
COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/infra/docker-compose.yml")
COMMAND="${1:-up}"

# 本地基础设施入口：统一读取 apps/api/.env，并复用 deploy/.data 数据目录。
usage() {
  cat <<'USAGE'
用法：
  scripts/infra.sh [up|down|restart|status|logs|wait|reset|config]

命令：
  up       启动 PostgreSQL、Redis、MinIO
  down     停止本地依赖容器
  restart  重启本地依赖容器
  status   查看容器状态
  logs     查看最近日志，可追加服务名
  wait     等待 PostgreSQL 就绪
  reset    删除 deploy/.data 并重新启动依赖
  config   输出 Docker Compose 展开后的配置

环境变量：
  ENV_FILE  覆盖 env 文件路径，默认 apps/api/.env。

数据目录：
  本地依赖数据保存在 deploy/.data/。
USAGE
}

if [[ "$COMMAND" == "--help" || "$COMMAND" == "-h" ]]; then
  usage
  exit 0
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "未找到 env 文件：$ENV_FILE" >&2
  echo "请先创建：cp apps/api/.env.example apps/api/.env" >&2
  exit 1
fi

# PostgreSQL 有 healthcheck，但后端本地运行前也显式等待一次，启动体验更稳定。
wait_postgres() {
  echo "等待 PostgreSQL 接受连接..."
  for attempt in {1..30}; do
    if "${COMPOSE[@]}" exec -T postgres pg_isready -U blog -d blog >/dev/null 2>&1; then
      return
    fi
    if [[ "$attempt" == "30" ]]; then
      echo "PostgreSQL 未在预期时间内就绪。可运行 'scripts/infra.sh logs postgres' 查看详情。" >&2
      exit 1
    fi
    sleep 1
  done
}

case "$COMMAND" in
  up)
    "${COMPOSE[@]}" up -d
    ;;
  down)
    "${COMPOSE[@]}" down
    ;;
  restart)
    "${COMPOSE[@]}" down
    "${COMPOSE[@]}" up -d
    ;;
  status)
    "${COMPOSE[@]}" ps
    ;;
  logs)
    "${COMPOSE[@]}" logs --tail=120 "${@:2}"
    ;;
  wait)
    wait_postgres
    ;;
  reset)
    "${COMPOSE[@]}" down
    rm -rf "$DATA_DIR"
    "${COMPOSE[@]}" up -d
    ;;
  config)
    "${COMPOSE[@]}" config
    ;;
  *)
    echo "未知命令：$COMMAND" >&2
    usage >&2
    exit 2
    ;;
esac
