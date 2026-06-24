# Spring Boot 4.1 与 Spring AI 2.0 升级说明

## 升级目标

| 组件 | 升级前 | 升级后 |
|------|--------|--------|
| Spring Boot | 4.0.6 | 4.1.0 |
| Spring AI | 2.0.0-RC2 | 2.0.0 |
| Java | 21 | 21 |

官方依据：

- [Spring Boot 4.1 Release Notes](https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-4.1-Release-Notes)
- [Spring AI 2.0.0 Release](https://github.com/spring-projects/spring-ai/releases/tag/v2.0.0)
- [Spring AI Upgrade Notes](https://docs.spring.io/spring-ai/reference/upgrade-notes.html)

## 依赖结果

Spring Boot 4.1.0 最终管理的主要运行时版本：

| 组件 | 解析版本 |
|------|----------|
| Spring Framework | 7.0.8 |
| Spring Data JPA | 4.1.0 |
| Hibernate ORM | 7.4.1.Final |
| Flyway | 12.4.0 |
| Spring AI | 2.0.0 |
| Testcontainers | 2.0.5 |

项目继续使用 Java 21。Boot 4.1 的最低要求仍是 Java 17，但没有必要降低项目基线。

## 已完成适配

### Maven

- `spring-boot-starter-parent` 更新为 `4.1.0`。
- `spring-ai-bom` 更新为 `2.0.0`。
- Spring AI OpenAI、Ollama、PGvector 和 JDBC ChatMemory Starter 名称保持不变。

### 模型配置

Spring AI 2.0 GA 推荐将模型选项直接放在模型配置下：

```yaml
spring:
  ai:
    openai:
      chat:
        model: ${OPENAI_CHAT_MODEL:gpt-4.1-mini}
        max-tokens: ${OPENAI_MAX_TOKENS:131072}
    ollama:
      embedding:
        model: ${OLLAMA_EMBEDDING_MODEL:nomic-embed-text}
```

旧的 `chat.options.max-tokens` 和 `embedding.options.model` 已迁移为扁平属性。

### JDBC ChatMemory

Spring AI 2.0 GA 的 PostgreSQL Schema 要求：

- `timestamp TIMESTAMP WITH TIME ZONE`
- `sequence_id BIGINT`
- `(conversation_id, timestamp)` 索引

当前重新部署版本已将该结构合并进 `V1__init_schema.sql`，新库直接创建最终列类型。

### Tool Calling 与流式响应

以下 API 在 GA 中仍兼容，无需替换：

- `ChatClient.prompt()`
- `.tools(blogTools)`
- `.toolContext(...)`
- `MessageChatMemoryAdvisor`
- `ChatMemory.CONVERSATION_ID`
- `EmbeddingModel.embed(...)`

Spring AI 2.0 的 Tool Calling Advisor 会管理多轮工具调用。项目不直接调用已废弃的底层工具执行 API，因此无需额外迁移。

### Spring Boot 4.1

项目未使用 Boot 4.1 已删除的弃用 API，也未命中配置属性移除清单。需要关注的依赖升级已通过编译和测试验证：

- Hibernate 7.4：自定义 `UserType` 和实体映射正常编译。
- Flyway 12.4：合并后的 `V1/V2` 初始化迁移可正常执行。
- Spring Data 4.1：Repository、Specification、分页和锁查询保持兼容。
- Spring Security：JWT、OAuth2 Client 和过滤器链保持兼容。
- Testcontainers 2.0：测试依赖改用 `testcontainers-junit-jupiter` 和 `testcontainers-postgresql` 模块坐标。

Apple Silicon 本地环境额外启用 `macos-aarch64-netty-dns` Maven Profile，
补充 Netty 的 `osx-aarch_64` DNS 原生库。该 Profile 不会在 Linux 生产环境激活。

## 验证命令

```bash
scripts/dev-api.sh test
scripts/dev-api.sh run local,github,ai

curl http://localhost:8080/actuator/health
```

启动后还应确认：

1. Flyway 已执行 `V1` 和 `V2`。
2. `spring_ai_chat_memory.sequence_id` 为 `bigint`。
3. `spring_ai_chat_memory.timestamp` 为 `timestamp with time zone`。
4. Ollama `nomic-embed-text` 能生成 768 维向量。
5. 同步和 SSE AI 对话均能调用知识库工具。
