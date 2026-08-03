# blog-mimo

一个前后端分离的个人博客 Monorepo，包含内容发布、用户互动、管理后台、AI 对话与知识库检索。

## 项目结构

```text
apps/
  api/          Java 25 + Spring Boot 4 后端
  web_flutter/  Flutter Web 前端
infra/          本地基础设施（PostgreSQL、Redis、MinIO）
deploy/         生产部署包（Caddy、docker-compose）
scripts/        本地开发脚本
docs/           架构、功能、接口、运行与部署文档
```

代码边界和命名约定见 [架构说明](docs/architecture.md)，完整资料入口见 [文档索引](docs/README.md)。

## 技术栈

- 后端：Java 25、Spring Boot 4.1.0、Spring AI 2.0.0、Spring Data JPA、Flyway
- 前端：Flutter 3.35.4、Dart 3.9.2、Riverpod、go_router、Dio
- 基础设施：PostgreSQL 18 + pgvector、Redis 7.4、MinIO、Docker Compose

## 快速启动

复制本地配置并填写需要的密钥。这个文件同时供 Docker 依赖和后端 API 使用：

```bash
cp apps/api/.env.example apps/api/.env
```

启动依赖和后端：

```bash
scripts/dev-api.sh
```

本地依赖也可以单独启动：

```bash
scripts/infra.sh up
```

启动前端：

```bash
cd apps/web_flutter
fvm flutter pub get
fvm flutter run -d chrome
```

开发配置和故障排查见 [运行手册](docs/runbook.md)。

## 验证

后端入口会执行 Spotless 格式检查、Checkstyle 源码卫生检查、测试、JaCoCo 覆盖率报告和最低阈值；前端需依次通过格式、静态分析、测试与 Web 构建：
后端完整验证会通过 Testcontainers 启动 PostgreSQL/pgvector，因此需要本机 Docker 守护进程可用。

```bash
scripts/dev-api.sh test

# 后端格式检查失败时自动修复 Java 布局和导入顺序
cd apps/api && ./mvnw spotless:apply

cd apps/web_flutter
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
fvm flutter build web --release --wasm
```

生产 Web 构建优先使用更紧凑的 SkWasm 渲染器，并保留 JavaScript + CanvasKit 兼容回退。项目固定使用 Java 25、Maven 3.9.16、FVM 3.2.1 和 Flutter 3.35.4；后端脚本默认使用 `apps/api/mvnw`，前端命令通过 `apps/web_flutter/.fvmrc` 解析 Flutter 版本，本地仍可通过 `MAVEN_BIN` 或 `FVM_BIN` 覆盖。JaCoCo HTML 报告生成在 `apps/api/target/site/jacoco/index.html`。

## 生产部署

本地构建并打包：

```bash
scripts/package-deploy.sh
```

部署包支持两种模式：

- 服务器已有 Caddy：默认模式，仅把 API/MinIO 发布到 `127.0.0.1`，宿主 Caddy
  直接服务 Flutter 静态文件并反向代理动态请求。
- 服务器无其他 Web 服务：启用 `bundled-caddy` profile，让容器 Caddy 独占
  80/443。

生产推荐使用 `/srv/blog-mimo/releases/<version>`、`current` 原子软链接和
`/srv/blog-mimo/shared/data` 持久化目录。新数据库会通过 Flyway V1–V4 初始化。
现有 Caddy、旧静态博客的并行验收、最终切换和回滚步骤见
[部署说明](docs/deployment.md)。

## 当前状态

核心业务闭环、管理后台、响应式前端、AI 工具调用与知识库已实现。后续工作以模块拆分、集成测试、可观测性和产品扩展为主，详见 [功能清单](docs/features.md)。
