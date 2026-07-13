# ADR 0001：以可验证的模块化单体作为演进目标

- 状态：已采纳
- 日期：2026-07-12

## 背景

项目是单团队维护的个人博客，后端以单个 Spring Boot 进程部署，共享 PostgreSQL、Redis 和 MinIO。现有代码已经按认证、用户、内容、互动、AI 等业务域分包，但模块之间仍存在 Repository、JPA Entity 和共享监听器层面的直接依赖。

Flutter Web 已按 feature 组织页面并使用 Riverpod，不过部分大型页面仍直接编排 API、认证令牌、SSE 和局部交互状态。

## 决策

保持 Monorepo、单 API 进程和共享数据库，将后端演进为可验证的模块化单体：

1. 模块内部维持 `infrastructure -> application -> domain` 依赖方向。
2. 外部系统通过模块自己的 `application/port` 接入，由 `infrastructure` 实现适配器。
3. 事件监听器归消费模块所有，`shared` 不承担跨业务编排。
4. 使用 ArchUnit 在测试阶段阻止共享内核反向依赖业务模块、领域层依赖上层以及应用层依赖基础设施。
5. Flutter 状态与网络编排逐步迁入 `features/<feature>/application`，页面留在 `presentation`；只在需要缓存、多数据源或测试替身时引入 Repository。

暂不拆分微服务。AI 聊天需要复用内容搜索、用户权限和互动写操作，当前独立部署会引入额外的一致性、鉴权和运维成本。

## 首批落地

- 将业务事件契约移回发布模块，并把内容缓存、评论审核、AI 消息审核和用户创建监听从共享监听器移回消费模块。
- 将 MinIO bucket 准备能力改为内容应用端口和内容基础设施适配器。
- 移除 `AuthenticatedUser` 对 `User` 实体的反向依赖。
- 加入 `ArchitectureBoundaryTest` 作为持续边界门禁。

## 第二批落地

- 通过 `OAuthAccountPort` 消除 `user -> auth` 反向依赖，由 auth 基础设施提供 OAuth 账户查询和解绑适配器。
- 增加 `user` 不得访问 `auth` 内部类型的自动架构规则，使身份边界依赖保持单向。
- 将 AI 对话状态、会话管理、SSE 订阅与取消生命周期迁入 `features/about/application` 的 auto-dispose Riverpod Controller。
- `about_page.dart` 只保留页面组合、滚动、对话框和登录导航；私有展示组件迁入 `features/about/presentation`，错误提示通过监听 Controller 状态呈现。

## 第三批落地

- `OAuthAccount` 与 `RefreshToken` 改为保存标量 `userId`，不再跨模块持有 `User` JPA Entity；数据库列和外键保持不变。
- 新增用户模块公开的 `UserAccountService`，认证、JWT 过滤器、GitHub OAuth 和管理员初始化不再直接注入 `UserRepository`。
- ArchUnit 新增 auth domain 不得依赖 user domain、auth 不得访问 UserRepository 的边界规则。
- 新增 PostgreSQL Testcontainers 集成测试，验证 OAuth 与刷新令牌在 Flyway 最终结构上的 UUID 外键读写。

## 第四批落地

- 用户模块通过 `IdentityUser` 暴露认证所需的不可变快照，auth 不再导入 `User` JPA Entity。
- GitHub OAuth 的昵称和头像更新收口到 `UserAccountService`，实体变更保持在用户模块事务边界内。
- JWT、登录注册、OAuth 回调、绑定流程和管理员初始化统一依赖用户模块公开 API。
- ArchUnit 新增 auth 不得依赖 `user/domain/model` 的规则，并用契约测试验证快照不会随实体后续变化而改变。

## 第五批落地

- `Comment`、`Like` 与 `ViewRecord` 改为保存标量 `contentId/userId`，移除跨模块 `@ManyToOne`。
- content 模块通过 `ContentInteractionService` 暴露发布状态校验、计数更新、批量摘要和媒体 URL 解析；user 模块批量返回 `IdentityUser` 快照。
- 互动列表批量加载内容与用户快照，避免解除 JPA 关联后产生 N+1 查询。
- ArchUnit 新增 interaction domain 不得依赖 content/user、interaction 不得依赖外部 domain 的规则。
- 新增 PostgreSQL Testcontainers 集成测试，验证评论、点赞和浏览记录在 Flyway 结构上的标量外键读写与派生查询。

## 第六批落地

- `AiChatSession` 与 `AiDailyQuota` 改为保存标量 `userId`，移除 AI chat 对用户 JPA Entity 的关联。
- `AiChatService` 通过 `UserAccountService` 校验活跃身份；管理端批量加载 `IdentityUser` 快照。
- 管理端会话关键词查询仍支持标题、邮箱和昵称：用户模块先返回匹配身份的 ID，AI 模块只在自身聚合上按 ID 过滤。
- ArchUnit 新增 AI chat domain 不得依赖 user、AI chat 模块不得依赖 user domain 的规则。
- 新增 PostgreSQL Testcontainers 集成测试，验证会话、每日配额、悲观锁查询和身份关键词查询。

## 第七批落地

- `AuditLog` 改为保存可空的 `actorUserId`，审计切面不再加载 `User` 实体或访问 `UserRepository`。
- 审计列表批量加载 `IdentityUser` 快照；用户删除后数据库通过 `ON DELETE SET NULL` 保留审计记录。
- 新增 ArchUnit 边界和 PostgreSQL 集成测试，验证标量映射、筛选及用户删除后的历史保留。

## 第八批落地

- content 模块移除对 `KnowledgeIndexService` 的反向调用，统一发布内容生命周期事件。
- AI 模块新增事件消费者，在事务提交后异步创建或删除内容向量索引。
- `ContentKnowledgeService` 作为 content 公开 API，向 AI 提供可索引正文、关键词摘要和批量标题快照。
- Knowledge index/search 不再导入 content 领域模型、Repository 或内部服务，并加入双向 ArchUnit 门禁。

## 第九批落地

- 管理概览改为组合 content、interaction、user、friend 和 AI 的模块指标 API，控制器不再直接注入九个业务 Repository。
- content 详情通过 `InteractionStateService` 查询当前用户点赞状态，移除 content 对 interaction Repository 的访问。
- `AdminDashboardService` 只负责跨模块指标组合，保持原有响应字段和 HTTP 合约。

## 第十批落地

- content 与 interaction 分别提供内容读取、互动操作和用户活动公开 API；AI 工具与用户控制器不再依赖外部模块内部 Service/DTO。
- `AiBlogTools` 只保留工具声明和身份提取，统一委托 `AiToolService`，删除重复映射和异常处理。
- `ContentMediaService` 统一向 auth、friend 和 user 暴露媒体 URL/存储能力。
- `UserProfileResponse` 移入 user `application/api`；admin 通过 audit 公开 API 查询日志。
- ArchUnit 增加管理概览、内容互动、AI 工具、媒体消费者、用户活动和审计消费者边界规则。

## 第十一批落地

- Flutter 认证页新增 `AuthFlowController`，集中管理登录/注册模式、记住邮箱、密码可见性、验证码倒计时和表单错误。
- 登录注册提交、验证码请求、凭据持久化与 GitHub OAuth 启动下沉到 application 层；页面仅保留输入控制器、表单校验、导航和反馈展示。
- Controller 使用 auto-dispose 生命周期，在释放时取消倒计时，并通过可覆盖的 OAuth launcher provider 隔离浏览器副作用。
- 认证页面入口与 presentation 实现分离，并新增状态恢复、邮箱校验和验证码倒计时单元测试。

## 第十二批落地

- 个人资料页迁入 feature application 层：`ProfileFormController` 统一管理 OAuth、头像上传、资料保存和密码更新。
- `ProfileActivityController` 管理评论、点赞和浏览记录的分页、重试与删除，页面不再直接调用活动 API 或持有分页业务状态。
- 页面入口与 presentation 实现分离，只保留输入/滚动控制器、文件选择、确认对话框、导航和 SnackBar 反馈。
- 浏览器跳转通过可覆盖 launcher provider 隔离，并新增表单校验、OAuth 映射及活动分页删除测试。

## 第十三批落地

- 主页新增 `HomeFeed` feature 视图模型，在 application 层完成精选内容选择与最新列表去重。
- 跨功能使用的推荐查询缓存继续保留在共享 state 层，主页只依赖自己的 `homeFeedProvider`；管理端失效缓存后会自动刷新主页映射。
- 主页入口与 presentation 实现分离，并新增精选优先级和回退逻辑测试。

## 第十四批落地

- 公开审计和用户活动 API 补直接契约测试，所有 `application/api` 服务均有测试引用。
- ArchUnit 新增通用跨模块门禁，禁止业务模块访问其他模块的 domain、内部 service/DTO 和 infrastructure；架构扫描显式排除测试夹具。
- 完成 Spring Modulith 评估并记录 ADR-0002：当前不引入需要忽略模块环的门禁，待消除 `content ↔ interaction` 环后优先以 test scope 试点。

## 后续顺序

1. 消除 `content ↔ interaction` 模块环，再试点 test-scope Spring Modulith。
2. 仅在出现独立扩缩容、不同发布周期或明确故障隔离需求时，优先拆出异步知识索引 worker。

## 影响

短期会增加少量端口和映射代码，但模块依赖可被自动验证，业务变化的影响范围更明确。部署拓扑和数据库事务模型保持不变，因此不引入分布式系统复杂度。
