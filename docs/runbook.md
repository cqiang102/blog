# 运行手册

## 依赖服务

```bash
docker compose -f infra/docker-compose.yml up -d
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

诊断模式，不连接 PostgreSQL/Flyway/pgvector：

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

自定义 Maven 路径：

```bash
MAVEN_BIN=/path/to/mvn scripts/dev-api.sh run local
```

默认本地 profile 不启用 GitHub OAuth，因此没有 GitHub 密钥也能启动。需要 GitHub 登录时使用：

```bash
scripts/dev-api.sh run local,github
```

默认本地 profile 不启用 Spring AI pgvector VectorStore，避免首版启动过早依赖 embedding 配置。需要验证 AI 向量检索时使用：

```bash
scripts/dev-api.sh run local,ai
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

完整升级记录见 [Spring Boot 4.1 与 Spring AI 2.0 升级说明](upgrade-spring-boot-4.1-spring-ai-2.0.md)。

只想先验证 Web/API 层、暂时不连接 PostgreSQL 时，可以使用诊断 profile：

```bash
scripts/dev-api.sh run local,nodb
```

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
