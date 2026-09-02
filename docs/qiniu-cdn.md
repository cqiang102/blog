# 七牛云 CDN 与证书自动化

> 博客静态资源与对象存储已迁移到七牛云（Kodo + CDN），本文记录架构、证书自动化、
> 构建/上传流程与故障排查，供后续维护参考。

## 1. 架构总览

```
浏览器
 ├─ https://blog.lacia.cn        → Caddy（服务器）：index.html + /api/* + flutter_bootstrap.js
 │                                 · index.html 的 <base> 保持同源 "/"（绝不能指向 CDN，见 5.5）
 │                                 · flutter_bootstrap.js 把资源基址指向 CDN，主包/引擎走七牛
 └─ https://static.blog.lacia.cn → 七牛 CDN（源站 lacia-public 公开空间）
                                    · /web/<sha>/ 版本化目录：main.dart.wasm、main.dart.mjs、
                                      canvaskit/、assets/、flutter_bootstrap.js 等
 └─ https://file.lacia.cn        → 七牛 CDN（源站 lacia-private 私有空间，签名 URL 访问）
```

| 域名 | 用途 | 源站 | 访问方式 |
|---|---|---|---|
| `blog.lacia.cn` | 页面 + API（Caddy 反代） | 服务器 | 公开 |
| `static.blog.lacia.cn` | 前端静态资源加速 | `lacia-public` | 公开，CDN 缓存 |
| `file.lacia.cn` | 后端上传文件 | `lacia-private` | 仅七牛签名 URL（下载凭证） |

七牛空间（均在华南 z2 区）：

| 空间 | 权限 | 用途 |
|---|---|---|
| `lacia-public` | 公开 | 仅 Flutter Web 静态资源（CDN 加速） |
| `lacia-private` | 私有 | 全部后端上传（媒体、头像等，签名访问） |
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

### 关键约束（重要，2026-09 修订）

1. 入口 `index.html` 的 `<base>` **必须保持同源**（`/`），**不能**改成 CDN 绝对地址。
   - 原因：Flutter Web 的 GoRouter 初始化会把 `Uri.base` 写入 `history.replaceState`；
     `<base>` 指向 CDN 时等于跨域写入 history，浏览器抛 `SecurityError`，Dart 侧变成
     `JavaScriptError`，最终页面 `ProviderException` 白屏（详见 5.5）。
   - 历史上 8/7 部署把 `<base>` 指向 `https://static.blog.lacia.cn/web/<sha>/` 导致全站白屏，
     修复方式见 5.5。
2. CDN 只承担 Flutter 主包/引擎等大文件：构建后**修改 `flutter_bootstrap.js`**，把资源解析基址
   `document.baseURI` 替换为 CDN 版本化目录，并**移除 `serviceWorkerSettings`**（入口与 CDN 跨域，
   Service Worker 无法注册，留着只会报错）。
3. **API 地址建议用绝对 URL**：`--dart-define=API_BASE_URL=https://blog.lacia.cn/api/v1`，
   保证媒体地址、SSE 等拼接不依赖 `Uri.base`（提交 `0c3212d` 起代码已按 API 地址解析）。
4. 每次发布使用**版本化目录** `web/<git-sha>/`（新 URL 天然绕过 CDN/浏览器旧缓存），
   旧目录可保留回滚，也可定期在七牛控制台清理。
5. Dart 引擎仍按页面 `document.baseURI` 加载 `assets/`（字体、AssetManifest 等小文件），
   所以发布时需把新构建的 `assets/` 同步到服务器入口目录，避免个别资源 404。

### 构建命令

```bash
SHA=$(git rev-parse --short HEAD)
cd apps/web_flutter
fvm flutter build web --release --wasm --tree-shake-icons \
  --base-href="/" \
  --dart-define=API_BASE_URL=https://blog.lacia.cn/api/v1
# 1) CanvasKit 本地化补丁（canvaskit/ 相对路径）
bash tool/patch_flutter_bootstrap.sh build/web
# 2) 把 flutter_bootstrap.js 的资源基址指向 CDN，并关闭跨域 ServiceWorker 注册
python3 - <<'PY'
import re
p = 'build/web/flutter_bootstrap.js'
s = open(p).read()
s = s.replace('document.baseURI', f'"https://static.blog.lacia.cn/web/{SHA}/"', 1)
s = re.sub(r'serviceWorkerSettings:\s*\{[^}]*\}\s*,\s*', '', s)
open(p, 'w').write(s)
PY
```

> 不要修改构建产物 `index.html` 的 `<base>`，保持 `/`。使用打包脚本时同样保持
> `WEB_BASE_HREF=/`，仅覆盖 `WEB_API_BASE_URL=https://blog.lacia.cn/api/v1`。

### 上传与部署

```bash
# 上传 build/web 到 lacia-public 的 web/<sha>/ 目录（含 main.dart.wasm、canvaskit 等）
QINIU_ACCESS_KEY=xxx QINIU_SECRET_KEY=xxx \
QINIU_BUCKET=lacia-public QINIU_PREFIX=web/<sha>/ \
scripts/qiniu-upload.sh

# 部署到服务器入口目录 /usr/local/docker/blog-mimo/web/：
#  - flutter_bootstrap.js：补丁后的版本（资源指向 CDN）
#  - index.html：仅在有改动时覆盖，<base> 保持 "/"
#  - assets/：同步新构建的小资源（字体、AssetManifest 等），让 Dart 引擎同源加载
scp apps/web_flutter/build/web/flutter_bootstrap.js \
  root@<server>:/usr/local/docker/blog-mimo/web/flutter_bootstrap.js
scp apps/web_flutter/build/web/index.html \
  root@<server>:/usr/local/docker/blog-mimo/web/index.html
rsync -a apps/web_flutter/build/web/assets/ \
  root@<server>:/usr/local/docker/blog-mimo/web/assets/
```

## 4. 脚本清单（仓库内）

| 脚本 | 作用 |
|---|---|
| `scripts/qiniu-upload.sh` + `scripts/qiniu_upload.py` | 上传 Flutter 构建产物到 Kodo，自动设置 `application/wasm` 等 MIME；默认前缀 `web/<git-sha>/` |
| `scripts/qiniu_cert_sync.py` | 证书同步：读取本地 PEM → 对比七牛 → 上传 → 绑定 CDN 域名 → 清理旧证书 |
| `deploy/qiniu-cert-sync/run.sh` | 服务器端包装：venv + 读取 env + 循环同步两个域名 |

## 5. 故障排查

### 5.1 （历史）API 404：请求打到了 static.blog.lacia.cn

- **历史现象**：`https://static.blog.lacia.cn/api/v1/...` 返回 404。
- **历史根因**：旧方案把 `<base>` 指向 CDN，`/api/v1` 这类以 `/` 开头的相对 URL 被解析到 CDN。
- **现状**：本方案入口 `<base>` 保持 `/`（见 5.5），不会再出现该问题；仍建议构建时使用绝对
  `API_BASE_URL=https://blog.lacia.cn/api/v1`（`resolveMediaUrl` 与 Markdown `/api/` 链接均按 API 地址解析）。
- 提交：`0c3212d fix(web): resolve /api links against API base, support absolute API_BASE_URL build`

### 5.2 Caddy 容器启动失败 `exec format error`

- 服务器是 x86_64，本机 Docker 默认构建的是 arm64。必须显式指定平台：
  `docker build --platform linux/amd64 -t caddy:2.11.4-alidns-amd64 .`

### 5.3 证书同步脚本卡住

- `GET /sslcert` 分页接口在最后一页仍返回 `marker`，旧版脚本会死循环。
- 已修复：无新数据或 marker 不变时结束（提交 `2ef0d5b`）。

### 5.4 域名 protocol=http 时绑定证书失败

- 未开启 HTTPS 的域名要先调 `/sslize`，已开启的用 `/httpsconf`；脚本会自动判断。

### 5.5 白屏 / ProviderException：入口 `<base>` 指向 CDN（跨域）

- **现象**（2026-08-07 部署后全站复现）：
  - 控制台：`SecurityError: Failed to register a ServiceWorker ... does not match the current origin`
  - `Manifest: property 'start_url' ignored, should be same origin as document`
  - `ProviderException: Tried to use a provider that is in error state.`（底层 `JavaScriptError`）
  - 页面停在 loading 或白屏，且**不会发出任何 API 请求**。
- **根因**：`index.html` 的 `<base href="https://static.blog.lacia.cn/web/<sha>/">` 指向 CDN。
  GoRouter（`usePathUrlStrategy`）启动时把 `Uri.base`（此时为 CDN 地址）写入
  `history.replaceState`；跨域 URL 被浏览器拒绝（SecurityError）→ Dart 侧 `JavaScriptError`
  → `routerProvider` 进入错误态 → 读取时抛 `ProviderException`。
- **修复**：
  1. 服务器入口 `index.html` 的 `<base>` 改回 `/`（备份旧文件后再改）。
  2. 按第 3 节用补丁版 `flutter_bootstrap.js`（资源基址指向 CDN、移除 `serviceWorkerSettings`），
     让 main.dart.wasm / canvaskit 仍走七牛 CDN。
- 服务器现状（2026-09-02 已修复）：
  - `/usr/local/docker/blog-mimo/web/index.html`：`<base href="/">`
  - `/usr/local/docker/blog-mimo/web/flutter_bootstrap.js`：补丁版（指向 `web/0c3212d/`）
  - 回滚备份：`index.html.bak-20260902-cdnbase`、`flutter_bootstrap.js.bak-20260902-sameorigin`

## 6. 相关文档

- `docs/deployment.md`：服务器部署总览
- `docs/runbook.md`：运维手册
