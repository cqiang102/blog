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

推荐启动方式。脚本会固定 Java 21 和 Maven 3.8.8，即使当前终端 `JAVA_HOME` 指向 Java 8 也会切到 Java 21：

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

手动启动方式：

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"
cd apps/api
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local
```

默认本地 profile 不启用 GitHub OAuth，因此没有 GitHub 密钥也能启动。需要 GitHub 登录时使用：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,github
```

默认本地 profile 不启用 Spring AI pgvector VectorStore，避免首版启动过早依赖 embedding 配置。需要验证 AI 向量检索时使用：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,ai
```

## Spring AI 升级说明

### 2.0.0-RC1 (当前版本)

已修复的问题：

| 问题 | 修复 |
|------|------|
| **Stream 流式响应缓冲** | `OpenAiChatModel.stream()` 现在只缓冲 tool calls，普通流式响应逐 token 返回 |
| **Tool 调用支持** | `ChatClient.tools()` 支持直接传入 `@Tool` 注解的对象 |

已移除的临时方案：

- `OpenAiChatModelStreamDecorator.java` — 用于绕过流式缓冲的临时装饰器，已删除
- `buildKnowledgeContext()` — 预先查询向量数据库的 workaround，已移除

当前实现：

- AI 通过 `.tools(blogTools)` 注册工具，自主决定何时调用 `searchKnowledge` 进行知识库搜索
- 流式响应不再需要自定义装饰器，直接使用 Spring AI 原生支持

### 已知限制

- `getDefaultOptions()` 已标记废弃，后续版本需关注迁移
- Hibernate `UserType` 接口部分方法已标记待删除，需关注 Hibernate 版本升级

只想先验证 Web/API 层、暂时不连接 PostgreSQL 时，可以使用诊断 profile：

```bash
/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn spring-boot:run -Dspring-boot.run.profiles=local,nodb
```

健康检查：

```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8080/api/v1/meta
```

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

- Maven 显示 Java 8：先执行 Java 21 切换命令，并优先使用 `/Users/caoqiang/wubihuan/apache-maven-3.8.8/bin/mvn`。
- OpenAI 不可用：确认 `OPENAI_API_KEY` 和 `OPENAI_BASE_URL`。
- GitHub 登录不可用：确认 OAuth App 的 callback URL 指向后端服务。
