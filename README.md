# 个人博客 Monorepo

这是一个前后端分离的个人博客项目骨架：

- `apps/api`：Java 21 + Spring Boot 4 + Spring AI 2 后端
- `apps/web_flutter`：Flutter Web 前端
- `infra`：PostgreSQL/pgvector、Redis、MinIO 的本地开发环境
- `docs`：需求、接口、开发计划和运行说明

## 技术栈

- Backend：Spring Boot 4.0.x、Spring Security、Spring Data JPA、Flyway、Spring AI 2.0.x
- Frontend：Flutter Web、go_router、flutter_riverpod
- Infra：PostgreSQL + pgvector、Redis、MinIO、Docker Compose
- AI：OpenAI 兼容接口，预留 RAG 和工具调用

## 本地启动

后端需要 Java 21。当前机器默认 `java` 指向 JDK 8，运行 Maven 前请显式切换：

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"
```

推荐用脚本启动后端，它会固定 Java 21 和 Maven 3.8.8，即使当前终端 `JAVA_HOME` 指向 Java 8 也会切到 Java 21，并在普通 `local` 模式下自动启动 Docker 依赖：

```bash
scripts/dev-api.sh
```

只想验证后端 Web/API 层、暂时不连接 PostgreSQL：

```bash
scripts/dev-api.sh local,nodb
```

查看依赖服务状态和日志：

```bash
scripts/dev-api.sh status
scripts/dev-api.sh logs
scripts/dev-api.sh app-log
scripts/dev-api.sh doctor
```

也可以手动启动基础设施：

```bash
docker compose -f infra/docker-compose.yml up -d
```

启动后端：

```bash
cd apps/api
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local
```

启用 GitHub 登录时额外加上 `github` profile，并配置 `GITHUB_CLIENT_ID`、`GITHUB_CLIENT_SECRET`：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,github
```

启用 Spring AI pgvector VectorStore 时额外加上 `ai` profile：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,ai
```

如果只是先验证后端 Web/API 层、暂时不连接 PostgreSQL，可以手动使用：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,nodb
```

如果本地数据库迁移失败后想重置开发数据，确认没有重要数据后执行：

```bash
scripts/dev-api.sh reset-db
```

启动前端：

```bash
cd apps/web_flutter
fvm flutter pub get
fvm flutter run -d chrome
```

## 配置

复制示例配置后填写本地密钥：

```bash
cp apps/api/.env.example apps/api/.env
```

关键环境变量：

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`
- `JWT_SECRET`

## 当前状态

本仓库已搭好 MVP 工程骨架、数据库迁移、核心 API 占位、Flutter 路由和页面框架。下一步可以按 `docs/development-plan.md` 逐阶段补真实业务实现。
