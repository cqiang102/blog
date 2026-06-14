# 部署说明

## 前置要求

- Docker 24.0+
- Docker Compose 2.20+
- 域名（可选，用于生产环境）
- SSL 证书（推荐使用 Let's Encrypt）

## 生产环境部署

### 1. 准备环境变量

```bash
cd infra
cp .env.example .env
```

编辑 `.env` 文件，填写以下必要配置：

| 变量 | 说明 | 必填 |
|------|------|------|
| `POSTGRES_PASSWORD` | PostgreSQL 密码 | ✅ |
| `REDIS_PASSWORD` | Redis 密码 | ✅ |
| `MINIO_ACCESS_KEY` | MinIO 访问密钥 | ✅ |
| `MINIO_SECRET_KEY` | MinIO 密钥 | ✅ |
| `OPENAI_API_KEY` | OpenAI API Key | ✅ |
| `OPENAI_BASE_URL` | OpenAI API 地址 | ✅ |
| `FRONTEND_BASE_URL` | 前端公开访问地址 | ✅ |
| `GITHUB_CLIENT_ID` | GitHub OAuth Client ID | ✅ |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth Client Secret | ✅ |
| `MAIL_HOST` | SMTP 服务器地址 | ✅ |
| `MAIL_PORT` | SMTP 服务器端口 | ✅ |
| `MAIL_USERNAME` | SMTP 登录账号/发件邮箱 | ✅ |
| `MAIL_PASSWORD` | SMTP 密码或授权码 | ✅ |
| `JWT_SECRET` | JWT 密钥（至少32字符） | ✅ |
| `ADMIN_EMAIL` | 管理员邮箱 | ✅ |
| `ADMIN_PASSWORD` | 管理员密码 | ✅ |
| `ADMIN_NICKNAME` | 管理员昵称 | ✅ |
| `BLOG_CORS_ALLOWED_ORIGINS` | 允许的前端域名 | ✅ |

### 2. 启动服务

```bash
cd infra
docker compose -f docker-compose.prod.yml up -d
```

### 3. 检查服务状态

```bash
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f
```

### 4. 访问应用

- 前端容器：仅宿主机可访问 `http://127.0.0.1:8080`
- 对外访问：通过下方宿主机 Nginx 配置使用您的域名
- API：通过前端同源地址的 `/api/` 访问
- MinIO：仅在 Compose 内网开放，通过 `/minio/` 提供媒体文件

## SSL/HTTPS 配置

### 使用 Nginx 反向代理

1. 安装 Nginx：

```bash
sudo apt update
sudo apt install nginx
```

2. 创建 Nginx 配置：

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

}
```

3. 获取 SSL 证书：

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## GitHub OAuth 配置

1. 访问 https://github.com/settings/developers
2. 创建新的 OAuth App
3. 填写信息：
   - Application name: 您的博客名称
   - Homepage URL: `https://yourdomain.com`
   - Authorization callback URL: `https://yourdomain.com/login/oauth2/code/github`
4. 获取 Client ID 和 Client Secret
5. 填入 `.env` 文件

## 数据备份

### PostgreSQL 备份

```bash
# 备份
docker compose -f docker-compose.prod.yml exec postgres pg_dump -U blog blog > backup_$(date +%Y%m%d).sql

# 恢复
docker compose -f docker-compose.prod.yml exec -T postgres psql -U blog blog < backup_20260601.sql
```

### MinIO 备份

```bash
# 安装 mc 客户端
brew install minio/stable/mc

# 配置
mc alias set local http://localhost:9000 blog_minio blog_minio_password

# 备份
mc mirror local/blog-media ./backup/minio/
```

## 监控

### 健康检查

```bash
# API 健康检查
docker compose -f docker-compose.prod.yml exec api \
  curl --fail http://localhost:8080/actuator/health/readiness

# 详细信息
docker compose -f docker-compose.prod.yml exec api \
  curl --fail http://localhost:8080/actuator/info
```

### 日志查看

```bash
# 查看所有服务日志
docker compose -f docker-compose.prod.yml logs -f

# 查看特定服务日志
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f postgres
```

## 故障排查

### 服务无法启动

```bash
# 检查容器状态
docker compose -f docker-compose.prod.yml ps

# 查看日志
docker compose -f docker-compose.prod.yml logs

# 重启服务
docker compose -f docker-compose.prod.yml restart
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 状态
docker compose -f docker-compose.prod.yml exec postgres pg_isready -U blog

# 进入 PostgreSQL 命令行
docker compose -f docker-compose.prod.yml exec postgres psql -U blog blog
```

### MinIO 连接失败

```bash
# 检查 MinIO 状态
docker compose -f docker-compose.prod.yml exec minio \
  curl --fail http://localhost:9000/minio/health/live
```

## 回滚流程

如果新版本出现问题，可以快速回滚：

```bash
# 停止当前服务
docker compose -f docker-compose.prod.yml down

# 恢复数据库备份
docker compose -f docker-compose.prod.yml up -d postgres
docker compose -f docker-compose.prod.yml exec -T postgres psql -U blog blog < backup_YYYYMMDD.sql

# 使用旧版本镜像启动
docker compose -f docker-compose.prod.yml up -d
```

## 性能优化

### PostgreSQL 优化

在 `docker-compose.prod.yml` 中添加 PostgreSQL 配置：

```yaml
postgres:
  command: >
    postgres
    -c shared_buffers=256MB
    -c effective_cache_size=768MB
    -c work_mem=4MB
    -c maintenance_work_mem=128MB
    -c max_connections=200
```

### Redis 优化

```yaml
redis:
  command: >
    redis-server
    --appendonly yes
    --requirepass ${REDIS_PASSWORD}
    --maxmemory 256mb
    --maxmemory-policy allkeys-lru
```
