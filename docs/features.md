# 功能清单

> 最后核对：2026-06-15。以代码、数据库迁移和 OpenAPI 输出为最终依据。

---

## 项目概览

| 项目 | 说明 |
|------|------|
| 类型 | 个人博客全栈应用 |
| 架构 | Monorepo（后端 + 前端 + 基础设施） |
| 后端 | Java 25 + Spring Boot 4.1.0 + Spring AI 2.0.0 |
| 前端 | Flutter Web 3.35.4 + Dart 3.9.2 |
| 数据库 | PostgreSQL 18 + pgvector |
| 缓存 | Redis 7.4 |
| 存储 | MinIO |
| AI | OpenAI 兼容聊天 API + Ollama nomic-embed-text 嵌入模型 |

---

## 一、用户认证（Auth）

### 1.1 邮箱密码登录

| 功能 | 状态 | 说明 |
|------|------|------|
| 用户注册 | ✅ | 邮箱 + 密码注册，邮箱自动转小写 |
| 用户登录 | ✅ | 邮箱 + 密码登录，返回 accessToken + refreshToken |
| Token 刷新 | ✅ | 使用 refreshToken 静默刷新 accessToken |
| 退出登录 | ✅ | 前端清除本地 token + 后端删除 refreshToken |
| 密码修改 | ✅ | 已登录用户修改密码（旧密码验证） |
| 管理员初始化 | ✅ | 启动时按环境变量自动创建管理员账户 |

### 1.2 GitHub OAuth2 登录

| 功能 | 状态 | 说明 |
|------|------|------|
| GitHub 登录 | ✅ | OAuth2 授权码流程 |
| 账户关联 | ✅ | 首次 OAuth 登录自动创建用户，后续自动关联 |
| Token 自动刷新 | ✅ | 前端 401 拦截器自动调用 refreshToken |

### 1.3 安全机制

| 功能 | 状态 | 说明 |
|------|------|------|
| JWT 认证 | ✅ | JWT 过滤器验证每个请求 |
| 角色权限 | ✅ | USER / ADMIN 两级角色 |
| API 限流 | ✅ | Redis 滑动窗口限流（按 IP），X-RateLimit-* 响应头 |
| CORS 配置 | ✅ | 支持配置允许的前端域名 |

---

## 二、内容管理（Content）

### 2.1 内容类型

| 类型 | 说明 |
|------|------|
| ARTICLE | Markdown 文章，可绑定封面和媒体资源 |
| IMAGE | 图片 |
| VIDEO | 视频 |

### 2.2 内容状态

| 状态 | 说明 |
|------|------|
| DRAFT | 草稿（仅管理员可见） |
| PUBLISHED | 已发布（公开可见） |
| ARCHIVED | 已归档（不显示） |

### 2.3 公开接口

| 功能 | 状态 | 说明 |
|------|------|------|
| 内容列表 | ✅ | 分页、搜索、标签筛选、时间范围筛选 |
| 内容详情 | ✅ | 完整正文、点赞数、浏览数、评论数 |
| 标签列表 | ✅ | 公开获取所有标签（独立 API） |
| 推荐内容 | ✅ | 置顶 + 最新 + 最热，Redis 缓存 5 分钟 |

### 2.4 管理员接口

| 功能 | 状态 | 说明 |
|------|------|------|
| 创建内容 | ✅ | 标题、摘要、正文、类型、标签、状态 |
| 更新内容 | ✅ | 修改内容所有字段 |
| 删除内容 | ✅ | 软删除（归档） |
| 媒体上传 | ✅ | 图片/视频上传到 MinIO |
| 管理媒体 | ✅ | 媒体资源 CRUD |

### 2.5 标签管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 创建标签 | ✅ | 名称 + slug |
| 编辑标签 | ✅ | 修改名称和 slug |
| 删除标签 | ✅ | 删除标签及关联 |
| 内容标签关联 | ✅ | 多对多关系 |

---

## 三、互动功能（Interaction）

### 3.1 评论

| 功能 | 状态 | 说明 |
|------|------|------|
| 发表评论 | ✅ | 已登录用户对内容发表评论 |
| 评论列表 | ✅ | 按内容分页展示 |
| 删除自己的评论 | ✅ | 前端 + 后端双重验证（authorId 匹配） |
| 管理员删除评论 | ✅ | 管理员可删除任意评论 |
| 评论状态管理 | ✅ | VISIBLE / DELETED 状态切换 |

### 3.2 点赞

| 功能 | 状态 | 说明 |
|------|------|------|
| 点赞 | ✅ | 已登录用户点赞内容 |
| 取消点赞 | ✅ | 取消之前的点赞 |
| 点赞状态查询 | ✅ | 查询当前用户是否已点赞 |
| 点赞数统计 | ✅ | 实时统计内容点赞数 |

### 3.3 浏览记录

| 功能 | 状态 | 说明 |
|------|------|------|
| 浏览记录 | ✅ | 记录用户/匿名访问 |
| 匿名去重 | ✅ | SHA-256(IP + User-Agent) 去重 |
| 浏览数统计 | ✅ | 实时统计内容浏览数 |

### 3.4 用户动态

| 功能 | 状态 | 说明 |
|------|------|------|
| 我的动态 | ✅ | 查看自己的评论、点赞、浏览记录 |
| 分页加载 | ✅ | 滚动加载更多 |

---

## 四、AI 助手（AI Chat）

### 4.1 对话功能

| 功能 | 状态 | 说明 |
|------|------|------|
| AI 对话 | ✅ | 与 AI 助手聊天，支持上下文记忆 |
| 流式响应 | ✅ | 通过 SSE 逐步返回模型输出 |
| 会话管理 | ✅ | 创建新会话、查看历史会话 |
| 消息持久化 | ✅ | 业务消息表统一存储并提供最近 20 条模型上下文 |
| 会话消息限制 | ✅ | 每个会话最多 40 条消息，超限需新建会话 |
| 自动加载最新会话 | ✅ | 打开页面自动加载最近一次会话 |

### 4.2 工具调用（Tool Calling）

| 工具 | 状态 | 说明 |
|------|------|------|
| searchContent | ✅ | 搜索博客文章（关键词匹配） |
| getContentDetail | ✅ | 获取文章详情 |
| searchKnowledge | ✅ | 搜索知识库（关键词优先 + 向量补充） |
| likeContent | ✅ | 给文章点赞 |
| unlikeContent | ✅ | 取消点赞 |
| commentContent | ✅ | 对文章发表评论 |
| listComments | ✅ | 查询文章评论及评论 ID |
| deleteComment | ✅ | 删除自己的评论 |

> **注**：当前使用 Spring AI 2.0.0 GA，工具调用循环由 Tool Calling Advisor 管理。

### 4.3 知识库（RAG）

| 功能 | 状态 | 说明 |
|------|------|------|
| 内容自动索引 | ✅ | 发布内容时自动向量化（标题+摘要+正文） |
| 向量分块 | ✅ | 500 字符/块，50 字符重叠 |
| 向量存储 | ✅ | pgvector 存储 768 维向量 |
| 相似度搜索 | ✅ | 余弦相似度 Top-K 搜索 |
| 内容更新重索引 | ✅ | 更新发布内容时自动重建向量索引 |
| 内容归档删索引 | ✅ | 归档内容自动删除向量索引 |
| 混合检索 | ✅ | 精确关键词优先，未命中时使用向量搜索，并过滤低相关结果 |

### 4.4 配额管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 每日提问限制 | ✅ | 默认每天 10 次（可配置） |
| Redis 缓存配额 | ✅ | 24 小时 TTL，DB 回退 |
| 剩余次数显示 | ✅ | 前端显示今日剩余提问次数 |

---

## 五、用户系统（User）

### 5.1 用户管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 用户注册 | ✅ | 邮箱密码注册 |
| 用户登录 | ✅ | 邮箱密码 + GitHub OAuth |
| 个人资料 | ✅ | 查看和修改个人资料 |
| 密码修改 | ✅ | 旧密码验证 + 新密码设置 |
| 用户状态 | ✅ | ACTIVE / DISABLED |

### 5.2 管理员用户管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 用户列表 | ✅ | 分页查看所有用户 |
| 创建用户 | ✅ | 管理员创建用户 |
| 编辑用户 | ✅ | 修改用户信息和角色 |
| 禁用用户 | ✅ | 禁用/启用用户 |
| 删除用户 | ✅ | 删除用户账户 |

---

## 六、管理后台（Admin）

### 6.1 仪表盘

| 功能 | 状态 | 说明 |
|------|------|------|
| 统计概览 | ✅ | 内容数、用户数、评论数、浏览数 |
| 审计日志 | ✅ | 操作记录查询（支持筛选） |

### 6.2 内容管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 内容列表 | ✅ | 分页、搜索、状态筛选 |
| 创建内容 | ✅ | Markdown 编辑器 |
| 编辑内容 | ✅ | 修改标题、摘要、正文、状态 |
| 删除内容 | ✅ | 归档处理 |
| 媒体管理 | ✅ | 上传、预览、删除媒体资源 |

### 6.3 互动管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 评论管理 | ✅ | 查看、删除、状态切换 |
| 点赞记录 | ✅ | 查看所有点赞记录 |
| 浏览记录 | ✅ | 查看所有浏览记录 |

### 6.4 用户管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 用户列表 | ✅ | 分页查看所有用户 |
| 用户操作 | ✅ | 创建、编辑、禁用、删除 |

### 6.5 标签管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 标签 CRUD | ✅ | 创建、编辑、删除标签 |

### 6.6 友链管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 友链 CRUD | ✅ | 创建、编辑、删除友链 |

### 6.7 AI 聊天管理

| 功能 | 状态 | 说明 |
|------|------|------|
| 会话列表 | ✅ | 查看所有用户的 AI 会话 |
| 会话详情 | ✅ | 查看会话消息历史 |
| 知识库管理 | ✅ | 知识文档 CRUD（手动上传） |

### 6.8 审计日志

| 功能 | 状态 | 说明 |
|------|------|------|
| 日志查询 | ✅ | 按操作类型、用户、时间筛选 |
| 自动记录 | ✅ | AOP 切面自动记录管理操作 |

---

## 七、页面功能（Frontend）

### 7.1 首页

| 功能 | 状态 | 说明 |
|------|------|------|
| 推荐内容 | ✅ | 置顶 + 最新 + 最热 |
| 响应式布局 | ✅ | 移动端 NavigationBar / 桌面端 NavigationRail |

### 7.2 内容列表页

| 功能 | 状态 | 说明 |
|------|------|------|
| 分页加载 | ✅ | 无限滚动加载更多 |
| 搜索 | ✅ | 标题、摘要、正文关键词搜索 |
| 标签筛选 | ✅ | 按标签过滤内容 |
| 时间筛选 | ✅ | 日期选择器筛选时间范围 |
| 内容类型 | ✅ | 显示内容类型标识 |

### 7.3 内容详情页

| 功能 | 状态 | 说明 |
|------|------|------|
| Markdown 渲染 | ✅ | 完整 Markdown 支持 |
| 视频播放 | ✅ | 内嵌视频播放器 |
| 图片展示 | ✅ | 图片内容展示 |
| 点赞 | ✅ | 登录后可点赞/取消点赞 |
| 评论 | ✅ | 发表评论、查看评论列表 |
| 删除评论 | ✅ | 删除自己的评论 |

### 7.4 关于页（AI 助手）

| 功能 | 状态 | 说明 |
|------|------|------|
| AI 聊天界面 | ✅ | 对话气泡、Markdown 渲染 |
| 会话管理 | ✅ | 新建会话、查看历史 |
| 剩余次数 | ✅ | 显示今日剩余提问次数 |
| 会话限制提示 | ✅ | 超过 40 条消息提示新建会话 |

### 7.5 个人中心

| 功能 | 状态 | 说明 |
|------|------|------|
| 个人资料 | ✅ | 查看和修改个人资料 |
| 密码修改 | ✅ | 旧密码验证 + 新密码 |
| 我的动态 | ✅ | 评论、点赞、浏览记录 |
| 分页加载 | ✅ | 滚动加载更多 |

### 7.6 管理后台

| 功能 | 状态 | 说明 |
|------|------|------|
| 仪表盘 | ✅ | 统计数据展示 |
| 内容管理 | ✅ | 12 个管理标签页 |
| 审计日志 | ✅ | 日志查询和筛选 |

### 7.7 登录/注册页

| 功能 | 状态 | 说明 |
|------|------|------|
| 邮箱密码登录 | ✅ | 登录表单 |
| 用户注册 | ✅ | 注册表单 |
| GitHub 登录 | ✅ | OAuth 按钮 |

### 7.8 友链页

| 功能 | 状态 | 说明 |
|------|------|------|
| 友链展示 | ✅ | 网格布局展示友链 |
| 跳转链接 | ✅ | 点击跳转到友链网站 |

---

## 八、基础设施（Infrastructure）

### 8.1 数据库

| 功能 | 状态 | 说明 |
|------|------|------|
| PostgreSQL 18 | ✅ | 主数据库 |
| pgvector | ✅ | 向量存储（768 维，HNSW 余弦索引） |
| Flyway 迁移 | ✅ | V1 当前最终结构，V2 初始种子数据 |
| 15+ 张表 | ✅ | users, contents, comments, likes, views, tags, media, friends, ai_sessions, ai_messages, knowledge_docs, knowledge_chunks, audit_logs, oauth_accounts, refresh_tokens |

### 8.2 缓存

| 功能 | 状态 | 说明 |
|------|------|------|
| Redis 缓存 | ✅ | 推荐内容缓存（5 分钟） |
| AI 配额缓存 | ✅ | 每日提问次数缓存（24 小时） |
| Token 存储 | ✅ | RefreshToken 持久化 |

### 8.3 文件存储

| 功能 | 状态 | 说明 |
|------|------|------|
| MinIO 对象存储 | ✅ | 图片、视频、文件上传 |
| 文件大小限制 | ✅ | 默认 50MB（可配置） |

### 8.4 容器化

| 功能 | 状态 | 说明 |
|------|------|------|
| 本地开发 | ✅ | scripts/infra.sh + infra/docker-compose.yml（PG18 + Redis + MinIO，共用 deploy/.data） |
| 生产部署 | ✅ | deploy/docker-compose.yml（默认复用宿主 Caddy，API/MinIO 仅回环暴露；可选容器 Caddy） |
| API 容器 | ✅ | eclipse-temurin:25-jre-noble 镜像 + 挂载 blog-api.jar（无需服务器构建） |
| Web 容器 | ✅ | caddy:2.11.4-alpine 镜像 + 挂载 web/ 和 Caddyfile（可选 bundled-caddy profile） |
| Caddy 配置 | ✅ | deploy/Caddyfile + Caddyfile.host.example（自动 HTTPS / 复用宿主 Caddy） |

### 8.5 监控

| 功能 | 状态 | 说明 |
|------|------|------|
| Actuator | ✅ | health 公开；info、metrics 等其余管理端点仅 ADMIN |
| 健康检查 | ✅ | Kubernetes 探针支持 |

---

## 九、开发工具

### 9.1 脚本

| 脚本 | 说明 |
|------|------|
| scripts/infra.sh | 本地依赖服务脚本（读取 apps/api/.env，管理 PostgreSQL、Redis、MinIO） |
| scripts/dev-api.sh | 后端开发脚本（切换 Java 25、按需启动依赖、运行应用或完整验证） |
| scripts/package-deploy.sh | 生产部署包脚本（先验证，再构建 JAR 和 Flutter Web 并组装 tar.gz） |

### 9.2 文档

| 文档 | 说明 |
|------|------|
| README.md | 项目说明、技术栈、本地启动 |
| `docs/README.md` | 文档索引与资料状态 |
| `docs/architecture.md` | 代码结构、模块边界和命名约定 |
| `docs/requirements.md` | 产品需求 |
| `docs/api-contract.md` | API 契约概览 |
| `docs/deployment.md` | 部署指南 |
| `docs/runbook.md` | 本地运行与故障排查 |

### 9.3 测试

| 检查 | 状态 | 说明 |
|------|------|------|
| 后端 CI | ✅ | Java 25 下执行 Spotless 格式、Checkstyle 源码卫生、测试和 JaCoCo 覆盖率门禁 |
| 前端 CI | ✅ | Flutter 3.35.4 下执行格式、静态分析、测试和 Web 构建 |
| 部署检查 | ✅ | `scripts/package-deploy.sh --check` 验证工具、部署文件和 Compose 配置 |

---

## 十、技术特性

### 10.1 后端架构

| 特性 | 说明 |
|------|------|
| 包结构 | 按业务模块分包（ai、auth、content、interaction、user、friend、audit、admin） |
| 分层 | `infrastructure/web` → `application` → `domain` |
| 异常处理 | 全局异常处理器 + BusinessException |
| 响应格式 | 统一 ApiResponse 包装 |
| 分页 | PageResponse 统一分页响应 |
| 校验 | Bean Validation（@Valid） |

### 10.2 前端架构

| 特性 | 说明 |
|------|------|
| 状态管理 | Riverpod（Provider） |
| 路由 | GoRouter（声明式路由） |
| HTTP 客户端 | 自封装 BlogApiClient（单例） |
| 主题 | Material 3 |
| 响应式 | NavigationRail（桌面）/ NavigationBar（移动端） |
| Token 管理 | SharedPreferences 存储 + 401 自动刷新 |

### 10.3 AI 集成

| 特性 | 说明 |
|------|------|
| Spring AI | 2.0.0 |
| 聊天模型 | GPT-4.1-mini |
| 嵌入模型 | Ollama nomic-embed-text（768 维） |
| 向量存储 | pgvector |
| 聊天记忆 | `ai_chat_messages` 最近 20 条（单一事实来源） |
| RAG | 内容自动索引 + 向量搜索 |
| Tool Calling | 8 个 `@Tool` 方法（搜索、详情、知识库、互动和评论管理） |

---

## 十一、配置项

### 11.1 环境变量

下表的“默认值”是 `dev` 配置或 `apps/api/.env.example` 的本地开发值。基础配置与 `prod` 配置不内置数据库、缓存、邮件、对象存储、跨域或认证凭据；生产部署必须通过环境变量显式提供。

| 变量 | 默认值 | 说明 |
|------|--------|------|
| POSTGRES_HOST | localhost | 数据库主机 |
| POSTGRES_PORT | 5432 | 数据库端口 |
| POSTGRES_DB | blog | 数据库名 |
| POSTGRES_USER | blog | 数据库用户 |
| POSTGRES_PASSWORD | blog | 数据库密码 |
| REDIS_HOST | localhost | Redis 主机 |
| REDIS_PORT | 6379 | Redis 端口 |
| REDIS_PASSWORD | blog_redis | Redis 密码 |
| MINIO_ENDPOINT | http://localhost:9000 | MinIO 地址 |
| MINIO_ACCESS_KEY | blog_minio | MinIO 访问密钥 |
| MINIO_SECRET_KEY | blog_minio_password | MinIO 秘密密钥 |
| MINIO_BUCKET | blog-media | MinIO 存储桶 |
| OPENAI_API_KEY | 开发占位值 | OpenAI API 密钥，生产必须配置 |
| OPENAI_BASE_URL | https://api.deepseek.com | OpenAI 兼容 API 地址 |
| OPENAI_CHAT_MODEL | deepseek-v4-flash | 聊天模型 |
| OLLAMA_EMBEDDING_MODEL | nomic-embed-text | 嵌入模型 |
| JWT_SECRET | change-me-to-a-long-random-secret | JWT 密钥；生产必填且至少 32 字符 |
| JWT_ACCESS_TOKEN_MINUTES | 30 | Access Token 有效期（分钟） |
| JWT_REFRESH_TOKEN_DAYS | 30 | Refresh Token 有效期（天） |
| AI_DAILY_QUESTION_LIMIT | 10 | 每日提问次数限制 |
| MEDIA_MAX_UPLOAD_SIZE | 50MB | 最大上传文件大小 |
| SERVER_PORT | 8080 | 服务端口 |
| FRONTEND_BASE_URL | http://localhost:3000 | 前端公开地址 |
| BLOG_CORS_ALLOWED_ORIGINS | 本地前端地址 | 允许的前端域名（逗号分隔）；生产必填 |

---

## 十二、数据库表

| 表名 | 说明 |
|------|------|
| users | 用户表 |
| oauth_accounts | OAuth 关联表 |
| refresh_tokens | 刷新令牌表 |
| contents | 内容表 |
| tags | 标签表 |
| content_tags | 内容-标签关联表 |
| media_assets | 媒体资源表 |
| comments | 评论表 |
| likes | 点赞表 |
| view_records | 浏览记录表 |
| friends | 友链表 |
| ai_chat_sessions | AI 会话表 |
| ai_chat_messages | AI 消息表，也是模型上下文的唯一事实来源 |
| ai_daily_quotas | AI 每日配额表 |
| knowledge_docs | 知识文档表 |
| knowledge_chunks | 知识分块表（含向量） |
| audit_logs | 审计日志表 |

---

## 十三、API 端点总览

接口统一使用 `/api/v1` 前缀。主要入口见 [API 契约概览](api-contract.md)，完整路径和字段以运行时 OpenAPI 为准：

- Swagger UI：`http://localhost:8080/swagger-ui.html`
- OpenAPI JSON：`http://localhost:8080/v3/api-docs`

---

## 十四、待优化 / 可扩展

| 方向 | 说明 |
|------|------|
| 内容版本历史 | 内容修改记录和版本回滚 |
| 评论 @ 回复 | 评论支持 @ 其他用户 |
| 内容草稿自动保存 | 编辑器自动保存草稿 |
| 多语言支持 | 国际化（i18n） |
| 图片压缩 | 上传图片自动压缩 |
| SEO 优化 | Meta 标签、Open Graph |
| RSS 订阅 | 生成 RSS Feed |
| 更多 OAuth | QQ、微信、Google 登录 |
| 数据导出 | 内容、评论导出 |
| 性能监控 | APM 集成 |

---

本文档用于功能盘点，不替代自动化测试、数据库迁移或 OpenAPI 契约。
