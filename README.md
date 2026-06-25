# blog-mimo

一个前后端分离的个人博客 Monorepo，包含内容发布、用户互动、管理后台、AI 对话与知识库检索。

## 项目结构

```text
apps/
  api/          Java 21 + Spring Boot 4 后端
  web_flutter/  Flutter Web 前端
infra/          本地基础设施（PostgreSQL、Redis、MinIO）
deploy/         生产部署包（Dockerfile、Nginx、docker-compose）
scripts/        本地开发脚本
docs/           架构、功能、接口、运行与部署文档
```

代码边界和命名约定见 [架构说明](docs/architecture.md)，完整资料入口见 [文档索引](docs/README.md)。

## 技术栈

- 后端：Java 21、Spring Boot 4.1.0、Spring AI 2.0.0、Spring Data JPA、Flyway
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

```bash
scripts/dev-api.sh test

cd apps/web_flutter
fvm flutter analyze
fvm flutter test
fvm flutter build web --release
```

## 生产部署

本地构建并打包：

```bash
scripts/package-deploy.sh
```

上传 `blog-mimo-1.0.0.tar.gz` 到服务器后：

```bash
tar xzf blog-mimo-1.0.0.tar.gz && cd blog-deploy
test -f .env || cp .env.example .env
vim .env   # 确认生产配置
docker compose up -d --build
```

生产数据持久化在解压目录同级的 `blog-deploy/.data/`，迁移服务器时保留整个 `blog-deploy/` 目录即可带上 PostgreSQL、Redis 和 MinIO 数据。`1.0.0` 面向新库部署，数据库重新部署时会通过 Flyway `V1/V2` 初始化当前最终结构和种子数据。

详细配置见 [部署说明](docs/deployment.md)。

## 当前状态

核心业务闭环、管理后台、响应式前端、AI 工具调用与知识库已实现。后续工作以模块拆分、集成测试、可观测性和产品扩展为主，详见 [功能清单](docs/features.md)。
