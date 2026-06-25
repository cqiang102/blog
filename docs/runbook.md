# 运行手册

## 依赖服务

```bash
cp apps/api/.env.example apps/api/.env
scripts/dev-api.sh
```

本地运行只维护 `apps/api/.env` 一份配置。脚本会把它同时加载给 Docker 依赖服务和 Spring Boot API。
本地 PostgreSQL、Redis 和 MinIO 数据保存在 `infra/data/`，与 `infra/docker-compose.yml` 同级。

如果只想手动启动依赖服务：

```bash
docker compose --env-file apps/api/.env -f infra/docker-compose.yml up -d
```

服务端口：

- PostgreSQL：`localhost:5432`
- Redis：`localhost:6379`
- MinIO API：`localhost:9000`
- MinIO Console：`localhost:9001`

## 后端

推荐启动方式。脚本会切换到 Java 21，默认使用 `PATH` 中的 Maven；可通过 `MAVEN_BIN` 覆盖：

```bash
scripts/dev-api.sh
```

脚本默认启用 `dev` profile。依赖服务已经启动时，可以跳过 Docker 编排：

```bash
SKIP_DOCKER=1 scripts/dev-api.sh run dev
```

查看依赖服务状态和日志：

```bash
scripts/dev-api.sh status
scripts/dev-api.sh logs
scripts/dev-api.sh app-log
scripts/dev-api.sh doctor
```

自定义 Maven 路径：

```bash
MAVEN_BIN=/path/to/mvn scripts/dev-api.sh run dev
```

本地 GitHub 登录不再使用额外 profile。需要验证 GitHub 登录时，填写 `apps/api/.env`：

```bash
GITHUB_CLIENT_ID=...
GITHUB_CLIENT_SECRET=...
```

默认本地 VectorStore 为 `none`，避免启动时强依赖 embedding 配置。需要验证 AI 向量检索时，在 `apps/api/.env` 中设置：

```bash
AI_VECTORSTORE_TYPE=pgvector
```

## Spring AI 升级说明

### 2.0.0 GA（当前版本）

当前版本组合：

- Spring Boot 4.1.0
- Spring AI 2.0.0
- Java 21
- Spring Framework 7.0.8
- Hibernate 7.4.1.Final
- Flyway 12.4.0

关键适配：

- AI 通过 `.tools(blogTools)` 注册工具；事实类问题先调用搜索工具，空查询用于浏览全部内容或知识来源
- 知识检索采用关键词优先、向量补充的混合策略，向量结果受 `AI_KNOWLEDGE_MIN_SIMILARITY` 阈值控制
- OpenAI 和 Ollama 模型属性使用 2.0 GA 的扁平配置形式
- JDBC ChatMemory 的 `timestamp` 使用 `TIMESTAMPTZ`，`sequence_id` 使用 `BIGINT`
- Tool Calling 循环由 Spring AI 的 Advisor 链负责，同步和流式调用保持同一套工具注册方式

健康检查：

```bash
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/health/readiness
curl http://localhost:8080/api/v1/meta
```

本地 SMTP 未配置时，聚合端点 `/actuator/health` 可能因邮件连接检查返回
`DOWN`；容器编排和可用性判断应使用上面的 liveness/readiness 端点。

如果数据库迁移失败后需要清空本地开发数据，确认没有重要数据后执行：

```bash
scripts/dev-api.sh reset-db
```

## 前端

```bash
cd apps/web_flutter
fvm flutter pub get
fvm flutter run -d chrome
```

## 常见问题

- Maven 显示 Java 8：优先通过 `scripts/dev-api.sh` 运行，脚本会切换到 Java 21。
- Maven 不在默认 `PATH`：通过 `MAVEN_BIN=/path/to/mvn scripts/dev-api.sh ...` 指定。
- OpenAI 不可用：确认 `OPENAI_API_KEY` 和 `OPENAI_BASE_URL`。
- GitHub 登录不可用：确认 OAuth App 的 callback URL 指向后端服务。
