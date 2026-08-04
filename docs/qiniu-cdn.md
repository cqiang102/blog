# 七牛云 CDN 与证书自动化

> 博客静态资源与对象存储已迁移到七牛云（Kodo + CDN），本文记录架构、证书自动化、
> 构建/上传流程与故障排查，供后续维护参考。

## 1. 架构总览

```
浏览器
 ├─ https://blog.lacia.cn        → Caddy（服务器）：index.html + /api/*
 │                                 · index.html 内 <base> 指向 CDN，所有静态资源走七牛
 └─ https://static.blog.lacia.cn → 七牛 CDN（源站 lacia-public 公开空间）
                                    · /web/<sha>/ 版本化目录：main.dart.wasm、main.dart.mjs、
                                      canvaskit/、assets/、flutter_bootstrap.js 等
 └─ https://file.lacia.cn        → 七牛 CDN（源站 lacia-private 私有空间，签名 URL 访问）
```

| 域名 | 用途 | 源站 | 访问方式 |
|---|---|---|---|
| `blog.lacia.cn` | 页面 + API（Caddy 反代） | 服务器 | 公开 |
| `static.blog.lacia.cn` | 前端静态资源加速 | `lacia-public` | 公开，CDN 缓存 |
| `file.lacia.cn` | 私有文件 | `lacia-private` | 仅七牛签名 URL（下载凭证） |

七牛空间（均在华南 z2 区）：

| 空间 | 权限 | 用途 |
|---|---|---|
| `lacia-public` | 公开 | Flutter Web 静态资源、公开媒体 |
| `lacia-private` | 私有 | 私有媒体（签名访问） |
| `lacia-dev` | - | 历史开发空间，未使用 |

## 2. 证书自动化（Caddy DNS-01 → 七牛）

### 原理

- `static.blog.lacia.cn` / `file.lacia.cn` 的 DNS 已 CNAME 到七牛 CDN，因此 HTTP-01 验证不可用。
- 服务器 Caddy 使用 **DNS-01 验证**（`caddy-dns/alidns` 插件），通过阿里云 DNS API 自动添加
  `_acme-challenge.*` TXT 记录，签发/续期 Let's Encrypt 证书（90 天自动续）。
- 每天 03:22 systemd timer 运行 `qiniu_cert_sync.py`：对比证书 `not_after`，变化时自动
  上传到七牛（`POST /sslcert`）并绑定 CDN 域名（`PUT /domain/<name>/sslize` 或 `/httpsconf`）。

### 服务器文件

| 路径 | 说明 |
|---|---|
| `/usr/local/docker/nginx-gateway/docker-compose.yml` | Caddy 使用 `caddy:2.11.4-alidns-amd64` 镜像 |
| `/usr/local/docker/nginx-gateway/caddy.env` | 阿里云 DNS AK/SK（chmod 600） |
| `/usr/local/docker/nginx-gateway/data/Caddyfile` | 站点配置（含 DNS-01 tls 块） |
| `/usr/local/docker/qiniu-cert-sync/` | 证书同步脚本 + env + systemd 单元 |
| `/etc/systemd/system/qiniu-cert-sync.{service,timer}` | 每日 03:22 自动同步 |

Caddyfile 相关片段：

```
static.blog.lacia.cn, file.lacia.cn {
	tls {
		dns alidns {
			access_key_id {$ALIDNS_ACCESS_KEY_ID}
			access_key_secret {$ALIDNS_ACCESS_KEY_SECRET}
		}
	}
	respond "ok" 200
}
```

### 手动同步

```bash
/usr/local/docker/qiniu-cert-sync/run.sh
```

### 密钥轮换注意事项

轮换任一密钥后必须同步更新：

- 阿里云 DNS AK/SK → `/usr/local/docker/nginx-gateway/caddy.env`（改后 `docker compose up -d` 重建 Caddy）
- 七牛 AK/SK → `/usr/local/docker/qiniu-cert-sync/env`（改后无需重启，定时任务自动读取）

## 3. 构建与发布（Flutter Web → CDN）

### 关键约束（重要）

1. `--base-href` 只接受**以 / 开头和结尾的路径**，不接受完整 URL。
2. 构建后必须把 index.html 的 `<base href="/web/<sha>/">` 替换为 CDN 完整地址
   `https://static.blog.lacia.cn/web/<sha>/`，否则静态资源不会走 CDN。
3. **API 地址必须用绝对 URL**：`--dart-define=API_BASE_URL=https://blog.lacia.cn/api/v1`。
   - 原因：`<base>` 指向 CDN 后，浏览器会把 `/api/v1` 这类**以 / 开头的相对路径也解析到 CDN 域名**，
     导致 API 404（详见“故障排查”）。
4. 每次发布使用**版本化目录** `web/<git-sha>/`（新 URL 天然绕过 CDN/浏览器旧缓存），
   旧目录可保留回滚，也可定期在七牛控制台清理。

### 构建命令

```bash
SHA=$(git rev-parse --short HEAD)
cd apps/web_flutter
fvm flutter build web --release --wasm --tree-shake-icons \
  --base-href="/web/$SHA/" \
  --dart-define=API_BASE_URL=https://blog.lacia.cn/api/v1
# 本地 CanvasKit 补丁（canvaskit/ 相对路径，会随 <base> 解析到 CDN）
bash tool/patch_flutter_bootstrap.sh build/web
# 把 <base> 改成 CDN 绝对地址
python3 - <<'PY'
import re
p='build/web/index.html'
s=open(p).read()
s=re.sub(r'<base href="[^"]*">', f'<base href="https://static.blog.lacia.cn/web/{SHA}/">', s, count=1)
open(p,'w').write(s)
PY
```

或使用打包脚本（支持变量覆盖）：

```bash
WEB_BASE_HREF=/web/<sha>/ \
WEB_API_BASE_URL=https://blog.lacia.cn/api/v1 \
scripts/package-deploy.sh
```

### 上传与部署

```bash
# 上传 build/web 到 lacia-public 的 web/<sha>/ 目录
QINIU_ACCESS_KEY=xxx QINIU_SECRET_KEY=xxx \
QINIU_BUCKET=lacia-public QINIU_PREFIX=web/<sha>/ \
scripts/qiniu-upload.sh

# 部署 index.html 到服务器（其余资源全部走 CDN）
scp apps/web_flutter/build/web/index.html \
  root@<server>:/usr/local/docker/blog-mimo/web/index.html
```

## 4. 脚本清单（仓库内）

| 脚本 | 作用 |
|---|---|
| `scripts/qiniu-upload.sh` + `scripts/qiniu_upload.py` | 上传 Flutter 构建产物到 Kodo，自动设置 `application/wasm` 等 MIME；默认前缀 `web/<git-sha>/` |
| `scripts/qiniu_cert_sync.py` | 证书同步：读取本地 PEM → 对比七牛 → 上传 → 绑定 CDN 域名 → 清理旧证书 |
| `deploy/qiniu-cert-sync/run.sh` | 服务器端包装：venv + 读取 env + 循环同步两个域名 |

## 5. 故障排查

### 5.1 API 404：请求打到了 static.blog.lacia.cn

- **现象**：`https://static.blog.lacia.cn/api/v1/...` 返回 404。
- **根因**：`<base>` 指向 CDN 后，所有以 `/` 开头的相对 URL（Dio 的 `/api/v1`、Markdown 里的
  `/api/v1/media-assets/...`）都会解析到 CDN 域名。
- **解决**：构建时使用绝对 `API_BASE_URL=https://blog.lacia.cn/api/v1`（代码内 `resolveMediaUrl`
  基于 API 地址拼接；Markdown 预览的 `/api/` 链接也按 API 地址解析，不再用 `Uri.base`）。
- 提交：`0c3212d fix(web): resolve /api links against API base, support absolute API_BASE_URL build`

### 5.2 Caddy 容器启动失败 `exec format error`

- 服务器是 x86_64，本机 Docker 默认构建的是 arm64。必须显式指定平台：
  `docker build --platform linux/amd64 -t caddy:2.11.4-alidns-amd64 .`

### 5.3 证书同步脚本卡住

- `GET /sslcert` 分页接口在最后一页仍返回 `marker`，旧版脚本会死循环。
- 已修复：无新数据或 marker 不变时结束（提交 `2ef0d5b`）。

### 5.4 域名 protocol=http 时绑定证书失败

- 未开启 HTTPS 的域名要先调 `/sslize`，已开启的用 `/httpsconf`；脚本会自动判断。

## 6. 相关文档

- `docs/deployment.md`：服务器部署总览
- `docs/runbook.md`：运维手册
