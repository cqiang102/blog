# 部署说明

## 前置要求

### 本地构建环境（macOS）

- FVM 3.2.1（按 `apps/web_flutter/.fvmrc` 安装并使用 Flutter 3.35.4）
- JDK 25+（脚本会在 macOS 上优先使用 `/usr/libexec/java_home -v 25`）
- Maven 由 `apps/api/mvnw` 固定为 3.9.16（首次执行需要联网下载）
- Docker Desktop 或 OrbStack

### 服务器环境

- Docker 24.0+
- Docker Compose 2.20+
- 宿主机 Caddy 2.11.4+（或使用部署包固定的 `caddy:2.11.4-alpine`）
- 公网域名，DNS 已指向服务器
- 防火墙放行 TCP 80/443 和 UDP 443；HTTPS 证书由 Caddy 自动申请和续期

## 本地构建打包

### 1. 一键打包

```bash
scripts/package-deploy.sh
```

该脚本会自动完成：
1. 检查 Dart 格式并执行 Flutter 静态分析、测试与 WebAssembly Web 构建
2. 执行 Maven `clean verify`（Spotless 格式、Checkstyle 源码卫生、测试、JaCoCo 覆盖率门禁）并生成 Spring Boot 可执行 JAR
3. 组装部署目录并打包成 `blog-mimo-1.0.0.tar.gz`

Flutter Web 使用 `--wasm` 构建：支持 WasmGC 的浏览器加载 Dart Wasm + SkWasm，不支持的浏览器自动回退到 JavaScript + CanvasKit。Caddy 会按 `.wasm` 扩展名提供正确的内容类型，并对可压缩响应启用 Zstandard/Gzip。

> 部署 JAR 会跳过 `api-docs` Maven profile，不包含 SpringDoc/Swagger UI 依赖；`/v3/api-docs` 和 `/swagger-ui.html` 在生产部署中预期为不可用。开发环境默认启用 `dev` profile，可继续使用 Swagger/OpenAPI 辅助调试。
> `--skip-build` 会复用现有前后端产物，同时跳过上述自动化验证，仅适合已经通过 CI 或本地完整验证后的产物。
> 部署包默认不包含 `deploy/.env`，避免数据库、OAuth、AI 等明文凭据进入压缩包。确实需要一并传输时可显式使用 `--include-env`，并应通过受控渠道传输和限制文件权限。

产出结构：

```text
blog-deploy/
├── docker-compose.yml      # 生产编排（全部使用预构建镜像 + 挂载产物）
├── Caddyfile               # 独占 80/443 时使用的容器 Caddy 配置
├── Caddyfile.host.example  # 合并到服务器现有 Caddy 的站点模板
├── DEPLOYMENT.md           # 随部署包携带的本说明
├── blog-api.jar            # Spring Boot 可执行 JAR
├── web/                    # Flutter build 产物
├── .data/                  # PostgreSQL、Redis、Caddy 持久化数据（对象存储已迁移到七牛云 Kodo）
│   ├── postgres/
│   ├── redis/
│   └── caddy/              # ACME 证书和 Caddy 运行配置
├── .env                    # 可选；仅使用 --include-env 时随包带入
└── .env.example
```

默认 `docker compose up` 不启动 `web` 服务：Flutter 静态文件由宿主机现有
Caddy 直接提供，API 只发布到 `127.0.0.1`。只有服务器没有其他
Web 服务器、且容器可以独占 80/443 时，才使用
`docker compose --profile bundled-caddy up`。

### 2. 本地脚本测试

快速检查本地工具、部署文件和 Docker Compose 配置，不执行构建：

```bash
scripts/package-deploy.sh --check
```

只测试部署目录组装和压缩包结构，可复用已有构建产物：

```bash
scripts/package-deploy.sh --skip-build
```

## 服务器部署：复用现有 Caddy，保留旧静态站

推荐拓扑如下：

```text
Internet
   │ 80/443
宿主机 Caddy（现有证书与旧站继续保留）
   ├── /              → /srv/blog-mimo/current/web
   ├── /api/*         → 127.0.0.1:18080 → API 容器
   └── 静态资源/媒体  → 七牛 CDN（static.blog.lacia.cn / file.lacia.cn，见 docs/qiniu-cdn.md）

/srv/blog-mimo/
   ├── current -> releases/1.0.0
   ├── releases/1.0.0/          # 不可变部署产物
   └── shared/
       ├── .env                 # 0600，绝不放进发布包
       └── data/                # PostgreSQL、Redis 持久化数据
```

旧静态博客的目录不删除、现有域名站点块不提前替换。先使用
`next.blog.lacia.cn` 验收，最终切换只发生在一次通过验证的 Caddy reload 中。
如果最终域名不是 `blog.lacia.cn`，将下文域名整体替换为实际值。

### 1. 先核验 SSH 主机指纹

出现 `REMOTE HOST IDENTIFICATION HAS CHANGED` 时不要使用
`StrictHostKeyChecking=no`，也不要直接删除 `known_hosts` 后盲目接受。先通过云厂商
控制台或其他可信通道，在服务器执行：

```bash
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

本机此前显示的是候选指纹
`SHA256:2HtDFBQUztBSvw6QkocwLMXvD972qkvfFZ5KV7Mx33A`；它只有与独立可信渠道
查询到的服务器指纹完全一致后才可信。确认后，本机才执行：

```bash
ssh-keygen -R lacia.cn
ssh root@lacia.cn
```

如果无法从独立可信渠道确认指纹，暂停部署。

### 2. 盘点并备份现有 Caddy/旧站

```bash
sudo caddy version
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl status caddy --no-pager
sudo ss -lntp | grep -E ':(80|443)\b'
sudo cp -a /etc/caddy/Caddyfile /etc/caddy/Caddyfile.pre-blog-mimo
```

若现有 Caddy 低于 2.11.4，先按当前安装来源升级并单独完成配置验证与 reload，
不要把 Caddy 升级和博客切流放在同一个不可分割步骤中。

记录旧站点的静态目录、域名和 Caddy 配置。如果主配置使用 `import` 管理站点，
后续把新站模板放入其已存在的 include 目录；否则将站点块手工合并到主
`Caddyfile`。同时备份实际会修改的 include 文件，并记录新建片段的路径。不要直接
覆盖整份现有配置。

### 3. 上传到版本化目录

```bash
# 本地执行；上传前必须已完成 SSH 指纹核验
scp blog-mimo-1.0.0.tar.gz root@lacia.cn:/tmp/

# 服务器执行
sudo install -d -m 0755 \
  /srv/blog-mimo/releases/1.0.0 \
  /srv/blog-mimo/shared/data/postgres \
  /srv/blog-mimo/shared/data/redis
sudo tar xzf /tmp/blog-mimo-1.0.0.tar.gz \
  -C /srv/blog-mimo/releases/1.0.0 \
  --strip-components=1
sudo ln -sfn /srv/blog-mimo/releases/1.0.0 /srv/blog-mimo/current
sudo find /srv/blog-mimo/releases/1.0.0/web -type d -exec chmod 0755 {} +
sudo find /srv/blog-mimo/releases/1.0.0/web -type f -exec chmod 0644 {} +
```

`1.0.0` 按新数据库部署。Flyway 会依次执行当前仓库的 V1–V4。不要把来源不明的
旧 PostgreSQL 数据目录直接挂载到新容器；有旧动态数据时应先单独备份并制定
导入方案。旧纯静态博客不使用本项目数据库，因此可继续原样保留。

系统上传的正文媒体保存为 `/api/v1/media-assets/{id}/file` 稳定路径，对象存储使用
七牛云 Kodo：公开对象走 `static.blog.lacia.cn` CDN 直链，私有对象走 `file.lacia.cn`
预签名 URL（旧 `/minio/{bucket}/{objectKey}` 引用仅作兼容解析）。存储配置见
`docs/qiniu-cdn.md`。

### 4. 配置共享环境变量

```bash
sudo cp /srv/blog-mimo/current/.env.example /srv/blog-mimo/shared/.env
sudo chmod 0600 /srv/blog-mimo/shared/.env
sudoedit /srv/blog-mimo/shared/.env
```

编辑 `.env` 文件，填写以下必要配置：

| 变量 | 说明 | 必填 |
|------|------|------|
| `DATA_DIR` | 固定为 `/srv/blog-mimo/shared/data` | ✅ |
| `API_BIND_ADDRESS` / `API_HOST_PORT` | 默认 `127.0.0.1:18080` | ✅ |
| `POSTGRES_PASSWORD` | PostgreSQL 密码 | ✅ |
| `REDIS_PASSWORD` | Redis 密码 | ✅ |
| `QINIU_ACCESS_KEY` | 七牛云 AccessKey | ✅ |
| `QINIU_SECRET_KEY` | 七牛云 SecretKey | ✅ |
| `QINIU_PUBLIC_BUCKET` / `QINIU_PUBLIC_DOMAIN` | 公开空间 `lacia-public` / `https://static.blog.lacia.cn/` | ✅ |
| `QINIU_PRIVATE_BUCKET` / `QINIU_PRIVATE_DOMAIN` | 私有空间 `lacia-private` / `https://file.lacia.cn/` | ✅ |
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
| `TRUSTED_PROXY_CIDRS` | 允许提供真实客户端 IP 的代理网段，默认 Docker 私网 | 可选 |
| `ADMIN_BOOTSTRAP_ENABLED` | 是否在启动时引导创建管理员（默认 `false`） | 可选 |
| `ADMIN_EMAIL` | 管理员邮箱（仅开启引导时需要） | 条件必填 |
| `ADMIN_PASSWORD` | 管理员密码（仅开启引导时需要） | 条件必填 |
| `ADMIN_NICKNAME` | 管理员昵称 | 可选 |

新环境需要创建首个管理员时，仅在首次启动前设置
`ADMIN_BOOTSTRAP_ENABLED=true` 并填写管理员邮箱、密码。账号创建后立即改回
`ADMIN_BOOTSTRAP_ENABLED=false`，避免后续启动继续携带引导凭据。

生产 Compose 会把 `host.docker.internal` 映射到 Linux 宿主机网关，供 API 容器访问
宿主机上的 Ollama。如果 Ollama 运行在其他主机，请显式设置 `OLLAMA_BASE_URL`。

预览阶段建议设置：

```dotenv
DATA_DIR=/srv/blog-mimo/shared/data
API_BIND_ADDRESS=127.0.0.1
API_HOST_PORT=18080
QINIU_ACCESS_KEY=your_qiniu_access_key
QINIU_SECRET_KEY=your_qiniu_secret_key
QINIU_PUBLIC_BUCKET=lacia-public
QINIU_PUBLIC_DOMAIN=https://static.blog.lacia.cn/
QINIU_PRIVATE_BUCKET=lacia-private
QINIU_PRIVATE_DOMAIN=https://file.lacia.cn/
FRONTEND_BASE_URL=https://next.blog.lacia.cn
BLOG_CORS_ALLOWED_ORIGINS=https://next.blog.lacia.cn,https://blog.lacia.cn
```

生成独立强密码和不少于 32 字符的随机 `JWT_SECRET`。首次创建管理员时临时开启
`ADMIN_BOOTSTRAP_ENABLED`，创建成功后立即关闭并清除共享 `.env` 中的管理员明文
密码。

### 5. 启动内部服务

默认模式不会启动容器 Caddy，也不会占用 80/443：

```bash
cd /srv/blog-mimo/current
sudo docker compose \
  --env-file /srv/blog-mimo/shared/.env \
  up -d --build
sudo docker compose \
  --env-file /srv/blog-mimo/shared/.env \
  ps
curl -fsS http://127.0.0.1:18080/actuator/health/readiness
```

确认 `docker compose ps` 中没有 `web` 服务，并确认下面两个端口只绑定到
`127.0.0.1`：

```bash
sudo ss -lntp | grep -E ':(18080|19000)\b'
```

### 6. 通过预览域名接入现有 Caddy

把部署包中的 `Caddyfile.host.example` 复制为一个新站点配置，将域名保持为
`next.blog.lacia.cn`。如果 API 回环端口有调整，同步修改模板。然后先格式化
新片段，再验证完整主配置：

```bash
sudo caddy fmt --overwrite /path/to/blog-mimo.caddy
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
```

只有主配置已通过 `caddy validate` 才执行 reload。旧博客的最终域名站点块此时
保持不变。预览 DNS 需先指向当前服务器。

预览检查：

```bash
curl -fsS https://next.blog.lacia.cn/api/v1/meta
curl -fsS https://next.blog.lacia.cn/api/v1/contents/recommendations
curl -I https://next.blog.lacia.cn/main.dart.wasm
curl -I https://next.blog.lacia.cn/flutter_bootstrap.js
sudo docker compose \
  --env-file /srv/blog-mimo/shared/.env \
  exec -T postgres sh -lc \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select version, description, success from flyway_schema_history order by installed_rank;"'
```

确认项：

- Flyway V1–V4 全部成功。
- `.wasm` 响应类型正确，`flutter_bootstrap.js` 不被长期缓存。
- 管理员账号可以登录，并能创建/编辑内容。
- 上传图片后前台可通过 `static.blog.lacia.cn` CDN 直链访问，私有文件通过 `file.lacia.cn` 预签名 URL 访问。
- GitHub OAuth、SMTP 验证码、AI 对话、Ollama embedding 按生产配置可用。

GitHub OAuth App 只能配置一个回调地址时，预览阶段可先不验收 GitHub 登录，或
临时使用 `https://next.blog.lacia.cn/login/oauth2/code/github`，切换前再改为最终
域名。

### 7. 切换最终域名

1. 把共享 `.env` 的 `FRONTEND_BASE_URL` 改为 `https://blog.lacia.cn`，CORS 可在
   过渡期保留预览和最终两个来源。
2. 把 GitHub OAuth Homepage/Callback 改为最终域名。
3. 重新创建 API 容器，使域名、Cookie 和预签名地址配置生效。
4. 把模板站点地址改为最终域名，并在 Caddy 中用其新站逻辑替换旧博客的最终域名
   站点块；旧静态文件目录仍不删除。
5. 验证完整配置后执行一次 `systemctl reload caddy`。

```bash
cd /srv/blog-mimo/current
sudo docker compose \
  --env-file /srv/blog-mimo/shared/.env \
  up -d --no-deps --force-recreate api
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
curl -fsS https://blog.lacia.cn/api/v1/meta
```

Caddy reload 是平滑的；验证失败时旧配置仍在运行。

### 8. 回滚

首次切换失败时，恢复切换前备份的 Caddy 配置并 reload，流量即可立即回到未删除的
旧静态博客。如果使用 include 目录，还要把本次新增的站点片段移出 include 目录，
并恢复被替换的旧站片段；下面命令适用于直接修改主 `Caddyfile` 的情况：

```bash
sudo cp -a /etc/caddy/Caddyfile.pre-blog-mimo /etc/caddy/Caddyfile
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
```

确认旧站恢复后，再决定是否停止新容器。不要执行 `docker compose down -v`，也不要
删除 `/srv/blog-mimo/shared/data`。数据库迁移后的 API 版本回滚需要单独评估迁移
兼容性；这不影响旧纯静态站的 Caddy 回切。

## 独占端口的全容器模式（可选）

只有宿主机没有 Caddy/其他 Web 服务时才使用：

```bash
sudo docker compose \
  --profile bundled-caddy \
  --env-file /srv/blog-mimo/shared/.env \
  up -d --build
```

该模式的容器 Caddy 使用 `Caddyfile`、监听 80/443，并把证书状态保存在
`.data/caddy`。它不能与宿主机现有 Caddy 同时运行。

## GitHub OAuth 配置

1. 访问 https://github.com/settings/developers
2. 创建新的 OAuth App
3. 填写信息：
   - Application name: 您的博客名称
   - Homepage URL: `https://blog.lacia.cn`
   - Authorization callback URL: `https://blog.lacia.cn/login/oauth2/code/github`
4. 获取 Client ID 和 Client Secret
5. 填入 `.env` 文件
