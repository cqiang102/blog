# 部署说明

## 前置要求

### 本地构建环境（macOS）

- Flutter 3.35.4（`fvm use 3.35.4`）
- JDK 21+（脚本会在 macOS 上优先使用 `/usr/libexec/java_home -v 21`）
- Maven 3.8+
- Docker Desktop 或 OrbStack

### 服务器环境

- Docker 24.0+
- Docker Compose 2.20+
- Nginx（宿主机，用于 SSL 终止和反向代理）
- 域名 + SSL 证书（推荐 Let's Encrypt）

## 本地构建打包

### 1. 一键打包

```bash
scripts/package-deploy.sh
```

该脚本会自动完成：
1. 构建 Flutter Web（`fvm flutter build web --release`）
2. 构建 Spring Boot 可执行 JAR（`mvn clean package -DskipTests -DskipApiDocs=true`）
3. 组装部署目录并打包成 `blog-mimo-1.0.0.tar.gz`

> 部署 JAR 会跳过 `api-docs` Maven profile，不包含 SpringDoc/Swagger UI 依赖；`/v3/api-docs` 和 `/swagger-ui.html` 在生产部署中预期为不可用。开发环境默认启用 `local` profile，可继续使用 Swagger/OpenAPI 辅助调试。

产出结构：

```text
blog-deploy/
├── Dockerfile.api          # Java 21 JRE + Spring Boot JAR
├── Dockerfile.web          # Nginx + Flutter 产物
├── docker-compose.yml      # 生产编排
├── nginx.conf              # 容器内 Nginx 配置
├── blog-api.jar            # Spring Boot 可执行 JAR
├── web/                    # Flutter build 产物
├── .data/                  # PostgreSQL、Redis、MinIO 持久化数据
│   ├── postgres/
│   ├── redis/
│   └── minio/
├── postgres/init/
│   └── 01-extensions.sql
└── .env.example
```

### 2. 本地脚本测试

快速检查本地工具、部署文件和 Docker Compose 配置，不执行构建：

```bash
scripts/package-deploy.sh --check
```

只测试部署目录组装和压缩包结构，可复用已有构建产物：

```bash
scripts/package-deploy.sh --skip-build
```

## 服务器部署

> `1.0.0` 是新库部署版本。Flyway 已合并为 `V1/V2` 初始化迁移，不支持将旧的 PostgreSQL 数据目录原地接到新包上继续迁移。上线前请备份旧数据；若重新部署数据库，请确保 `blog-deploy/.data/postgres` 为空目录。

### 1. 上传并解压

```bash
# 本地执行
scp blog-mimo-1.0.0.tar.gz user@your-server:/opt/blog/

# 服务器上执行
cd /opt/blog
tar xzf blog-mimo-1.0.0.tar.gz
```

部署目录中的 `.data/` 与 `docker-compose.yml` 同级，用于持久化 PostgreSQL、Redis 和 MinIO 数据。迁移或备份整套服务时，保留或打包整个 `blog-deploy/` 目录即可带上运行数据。系统上传的文章媒体会保存为 `/api/v1/media-assets/{id}/file` 稳定路径，头像等直接对象存储链接会保存为 `/minio/{bucket}/{objectKey}` 稳定路径，对外访问时再由当前部署动态生成可访问 URL。数据库重新部署时会通过 Flyway `V1/V2` 初始化当前最终结构和种子数据。

### 2. 配置环境变量

```bash
cp .env.example .env
vim .env
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
| `OPENAI_CHAT_MODEL` | 聊天模型名称 | ✅ |
| `FRONTEND_BASE_URL` | 前端公开访问地址 | ✅ |
| `BLOG_CORS_ALLOWED_ORIGINS` | 允许的前端域名 | ✅ |
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
| `WEB_PORT` | 前端容器端口（默认 8080） | 可选 |

### 3. 启动服务

```bash
docker compose up -d --build
```

### 4. 检查服务状态

```bash
docker compose ps
docker compose logs -f api
```

### 5. 访问应用

- 前端容器：仅宿主机可访问 `http://127.0.0.1:8080`
- 对外访问：通过宿主机 Nginx 使用您的域名
- API：通过前端同源地址的 `/api/` 访问
- MinIO：通过 `/minio/` 提供媒体文件（Docker 内部网络代理）

### 6. 上线冒烟检查

```bash
docker compose ps
curl -fsS http://127.0.0.1:${WEB_PORT:-8080}/api/v1/meta
curl -fsS http://127.0.0.1:${WEB_PORT:-8080}/api/v1/contents/recommendations
docker compose exec -T postgres sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select version, description, success from flyway_schema_history order by installed_rank;"'
```

确认项：

- Flyway 只包含 `1 init schema` 和 `2 seed initial data`。
- 管理员账号可以登录，并能创建/编辑内容。
- 上传图片后前台可通过当前域名访问，不出现 `http://minio:9000/...`。
- GitHub OAuth、SMTP 验证码、AI 对话、Ollama embedding 按生产配置可用。

## SSL/HTTPS 配置

### 宿主机 Nginx 反向代理

1. 安装 Nginx：

```bash
sudo apt update
sudo apt install nginx
```

2. 创建 Nginx 配置：

```nginx
server {
    listen 80;
    server_name blog.lacia.cn;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name blog.lacia.cn;

    ssl_certificate /etc/letsencrypt/live/blog.lacia.cn/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/blog.lacia.cn/privkey.pem;

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
sudo certbot --nginx -d blog.lacia.cn
```

## GitHub OAuth 配置

1. 访问 https://github.com/settings/developers
2. 创建新的 OAuth App
3. 填写信息：
   - Application name: 您的博客名称
   - Homepage URL: `https://blog.lacia.cn`
   - Authorization callback URL: `https://blog.lacia.cn/login/oauth2/code/github`
4. 获取 Client ID 和 Client Secret
5. 填入 `.env` 文件
