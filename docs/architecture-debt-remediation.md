# 架构债务修复方案

> 创建日期：2026-07-31
> 状态：方案设计完成，待实施
> 关联 ADR：ADR-0001（模块化单体）

---

## 问题一：数据加载分层不完整

### 现状分析

已完成分层重构的模块（首页、认证、个人中心）具备良好的内聚性：
- `home/application/home_feed_provider.dart` — 将推荐数据聚合下沉到 feature
- `profile/application/profile_activity_controller.dart` — 分页、删除、状态管理完整下沉
- `profile/application/profile_form_controller.dart` — 资料编辑流程状态内聚

**仍然悬浮在全局 `state/` 层的数据加载逻辑**：

| 全局 Provider | 归属页面 | 问题 |
|---------------|----------|------|
| `content_providers.dart`（部分） | 内容列表 / 详情 | `contentPaginationProvider` 和 `contentFilterProvider` 跨 feature 共享，但内聚性不强；分页逻辑未封装为独立 Controller |
| `commentsProvider` | 内容详情页 | 直接挂在全局，未纳入 `content_detail` feature 管理 |
| `admin_providers.dart`（全文件） | 管理后台全部 Tab | 14+ 个 `FutureProvider` 集中在一个文件，业务逻辑（token 校验、分页、筛选）与全局 Provider 混杂 |
| `userActivityProvider` | 个人中心 activity 列表 | 与 `profile_activity_controller` 功能重叠，存在两条数据路径 |
| `friendsProvider` | 友链页 | 简单接口，但未纳入 feature 内部 |

### 修复方案

#### 阶段 1：content 模块下沉

目标：将内容和评论相关数据逻辑内聚到 `features/content` 下。

```
features/content/
  content_detail/
    application/
      content_detail_controller.dart    ← 新建：管理详情+评论+浏览记录状态
  content_list/
    application/
      content_list_controller.dart       ← 新建：管理列表分页+筛选状态
```

**`content_detail_controller.dart`**（Riverpod Notifier）：
- 聚合 `contentDetailProvider` + `commentsProvider` + 浏览记录去重逻辑
- 管理 `viewRecorded` 状态（当前散落在 `StatefulWidget` 内）
- 提供 `recordView()`、`loadComments()`、`submitComment()` 等方法

**`content_list_controller.dart`**（Riverpod Notifier）：
- 合并现有的 `contentFilterProvider` + `contentPaginationProvider`
- 管理筛选 → 分页重置 → 加载更多 → 错误重试的完整流程

#### 阶段 2：admin 模块下沉

目标：消除 `admin_providers.dart` 上帝文件。

```
features/admin/
  application/
    admin_dashboard_controller.dart      ← 仪表盘数据
    admin_content_controller.dart        ← 内容管理列表
    admin_interaction_controller.dart    ← 评论/点赞/浏览管理
    admin_user_controller.dart           ← 用户管理
    admin_ai_chat_controller.dart        ← AI 会话管理
    admin_knowledge_controller.dart      ← 知识库管理
    admin_friend_controller.dart         ← 友链管理
    admin_tag_controller.dart            ← 标签管理
    admin_media_controller.dart          ← 媒体管理
```

每个 Controller 承担：
- API 调用所需的 token 获取
- 分页状态（page, size, total, hasMore）
- 筛选/搜索条件
- CRUD 操作命令（create / update / delete）

#### 阶段 3：清理全局 state 目录

下沉完成后，预期全局 `state/` 仅保留：
- `api_providers.dart` — `apiClientProvider` 等基础设施
- `auth_controller.dart` — 认证状态（全局共享）
- `content_filter_state.dart` — 筛选参数模型（可移入 content/feature/models）

---

## 问题二：content ↔ interaction 循环依赖

### 循环依赖的精确链路

通过源码分析，交叉点集中在两处：

**1. interaction → content（已有正确的反向端口，无需修改）**

```
InteractionCommandService
  └── ContentInteractionService         ← content 的 application/api 端口
        ├── findPublished()             ← 发布状态校验
        ├── incrementLikeCount()        ← 点赞计数更新
        ├── incrementViewCount()        ← 浏览计数更新
        ├── incrementCommentCount()     ← 评论计数更新
        └── findByIds()                 ← 内容标题快照（用于展示评论关联的文章）

InteractionQueryService + InteractionReferenceData
  └── ContentInteractionService         ← 同上（用于评论列表展示文章标题）
```

ArchUnit 验证通过：interaction 只访问 `content.application.api` 包。

**2. content → interaction（需要解耦）**

交叉点 A — `ContentQueryService`：
```java
import com.caoqiang.blog.interaction.application.api.InteractionStateService;
// ...
boolean liked = currentUser != null && interactionStateService.isLiked(id, currentUser.id());
```

交叉点 B — `ContentCacheEventListener`：
```java
import com.caoqiang.blog.interaction.event.LikeAddedEvent;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
```

**为什么这是循环依赖**：
- `interaction` 模块依赖 `content.application.api`（已合规）
- `content` 模块反向依赖 `interaction.application.api` + `interaction.event`（形成环）
- ArchUnit 规则允许双向公开 API 访问，但模块间存在双向耦合，不利于独立演进和测试

### 修复方案：分层解耦

#### 解耦交叉点 A：下沉到基础设施层

核心思路：**`liked` 状态查询从 application 层移到 infrastructure 层（Controller），解除 content 领域服务对 interaction 的运行期依赖。**

```
┌─────────────────────────────────────────────────────────────┐
│ 解耦前                                                       │
│                                                              │
│  ContentQueryService (application)                           │
│    └── 查 Content                                            │
│    └── InteractionStateService.isLiked()  ← application 耦合  │
│                                                              │
│  ContentController (infrastructure)                          │
│    └── 直接返回 ContentDetailResponse                        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ 解耦后                                                       │
│                                                              │
│  ContentQueryService (application)                           │
│    └── 查 Content（不再 import interaction）                 │
│    └── detail() 签名移除 currentUser 参数                    │
│                                                              │
│  ContentController (infrastructure)                           │
│    ├── contentQueryService.detail(id)                        │
│    └── interactionStateService.isLiked(id, userId)            │
│    └── 组装 ContentDetailResponse（手动设置 liked）          │
└─────────────────────────────────────────────────────────────┘
```

**具体代码变更**：

1. **`ContentQueryService.detail()` 移除 `InteractionStateService` 和 `currentUser`**
   - 删除 `import com.caoqiang.blog.interaction.application.api.InteractionStateService`
   - 删除 `private final InteractionStateService interactionStateService` 字段
   - 方法签名改为 `detail(UUID id)` — 不再接收 `AuthenticatedUser`
   - 返回的 `ContentDetailResponse` 中 `liked` 置为 `false`

2. **`ContentController.detail()` 组装 liked 状态**
   - 注入 `InteractionStateService`
   - 分别调用 `contentQueryService.detail(id)` 和 `interactionStateService.isLiked(id, currentUser.id())`
   - 返回时将 `liked` 设置到响应中

**评价**：
- 优点：content 的 application 层不再依赖 interaction 运行时，仅 infrastructure 层交叉
- 优点：不破坏 API 契约，前端无需任何适配
- 优点：保持单次 HTTP 请求
- 代价：Controller 构造响应时多一些手动代码

#### 解耦交叉点 B：缓存失效由 content 自行完成

核心思路：**`ContentCacheEventListener` 不再直接监听 interaction 事件，改为 content 自己的事件。**

当前问题：content 缓存推荐列表，但推荐排序依赖 like_count；interaction 触发 `LikeAddedEvent` 后，content 的缓存需要失效。

**解决方案**：将 like_count 变化作为 content 自己的事件。

当前状态：
```java
// interaction 模块发布
contentInteractionService.incrementLikeCount(contentId, 1);
domainEventPublisher.publishEvent(new LikeAddedEvent(contentId, userId));
```

改进后（在 `ContentInteractionService.incrementLikeCount` 内部增加 content 自己的事件发布）：
```java
// 在 ContentInteractionService（属于 content 模块的应用层）中
@Transactional
public void incrementLikeCount(UUID contentId, long delta) {
    contentRepository.incrementLikeCount(contentId, delta);
    domainEventPublisher.publishEvent(new ContentInteractionChangedEvent(contentId));
}
```

Content 模块监听自己的事件：
```java
// 新的 ContentInteractionChangedEvent 由 content 自己定义和发布
public class ContentCacheEventListener {
    @TransactionalEventListener
    public void onContentInteractionChanged(ContentInteractionChangedEvent event) {
        evictRecommendationsCache();
    }
    // 移除 @TransactionalEventListener onLikeAdded / onLikeRemoved
    // 移除 import interaction.event.LikeAddedEvent / LikeRemovedEvent
}
```

---

### 推荐策略组合

| 交叉点 | 策略 | 理由 |
|--------|------|------|
| 交叉点 A：ContentQueryService 查 liked | 下沉到 infrastructure 层 | liked 属于 UI 聚合问题，Controller 天然承担组合职责；不涉及前端改动 |
| 交叉点 B：缓存失效监听 LikeEvent | 事件吸收到 content | 移除对 interaction 事件的直接依赖，由 ContentInteractionService 内部转译 |

总体修改范围（估算）：
- 后端 Java：~5 个文件修改（ContentQueryService、ContentController、ContentInteractionService、ContentCacheEventListener、ContentInteractionChangedEvent）
- 新增代码：~1 个新事件类
- 前端 Dart：无需修改

---

## 修复后模块依赖图（目标状态）

```
修复前的环：
  interaction ←→ content

修复后的有向无环图：
  interaction → content（application/api）
  content     → (无 interaction 依赖)
```

```
┌───────────────────────────────────────────────────────┐
│                  依赖方向（无环）                        │
│                                                        │
│  friend ─────► content（application/api）              │
│  interaction ─► content（application/api）             │
│  ai.chat ─────► content（application/api, via tools）  │
│  ai.chat ─────► interaction（application/api, via tools）│
│  ai.knowledge ► content（application/api）             │
│  admin ───────► 各模块 application/api                 │
│                                                        │
│  content     ──► (独立，无业务模块依赖)                  │
└───────────────────────────────────────────────────────┘
```

---

## 新增 ArchUnit 规则

解耦后，在 `ArchitectureBoundaryTest` 中补充以下规则固化成果：

```java
@Test
void contentApplicationMustNotDependOnInteractionApi() {
    noClasses()
            .that()
            .resideInAPackage("com.caoqiang.blog.content.application..")
            .should()
            .dependOnClassesThat()
            .resideInAnyPackage(
                    "com.caoqiang.blog.interaction.application.service..",
                    "com.caoqiang.blog.interaction.application.dto..")
            .because("content application layer must not depend on interaction; "
                    + "cross-module state composition belongs in the web adapter")
            .check(applicationClasses);
}

@Test
void contentApplicationMustNotSubscribeToInteractionEvents() {
    noClasses()
            .that()
            .resideInAPackage("com.caoqiang.blog.content.application..")
            .should()
            .dependOnClassesThat()
            .resideInAPackage("com.caoqiang.blog.interaction.event..")
            .because("content cache reconciliation listens to its own ContentInteractionChangedEvent")
            .check(applicationClasses);
}
```

注意：`content.infrastructure.web` 允许注入并使用 `InteractionStateService`，因为 Controller 天然负责协议适配和跨域数据组合，这与现有 `webAdaptersMustNotAccessDomainRepositoriesDirectly` 规则的理念一致 — infrastructure 层可以使用其他模块的 application/api。

---

## 实施步骤建议

### 第一批：消除交叉点 B（低风险）
1. [ ] 创建 `ContentInteractionChangedEvent` 事件类（位于 `content/application/event/`）
2. [ ] 修改 `ContentInteractionService.incrementLikeCount/ViewCount/CommentCount`：在内部发布 `ContentInteractionChangedEvent`
3. [ ] 修改 `ContentCacheEventListener`：监听 `ContentInteractionChangedEvent` 替代 `LikeAddedEvent`/`LikeRemovedEvent`
4. [ ] 新增 ArchUnit 规则：`contentApplicationMustNotSubscribeToInteractionEvents()`
5. [ ] 验证 `ArchitectureBoundaryTest` 仍通过
6. [ ] 验证集成测试仍通过

### 第二批：下沉交叉点 A 到 infrastructure 层
7. [ ] 修改 `ContentQueryService.detail()`：移除 `currentUser` 参数和 `InteractionStateService` 依赖
8. [ ] 修改 `ContentController.detail()`：注入 `InteractionStateService`，组装 liked 状态后返回
9. [ ] 新增 ArchUnit 规则：`contentApplicationMustNotDependOnInteractionApi()` + `contentApplicationMustNotSubscribeToInteractionEvents()`
10. [ ] 更新契约测试
11. [ ] `mvnw test` 全量验证

### 第三批：前端 content 状态下沉
12. [ ] 创建 `content_detail_controller.dart`（聚合详情+评论+浏览记录）
13. [ ] 创建 `content_list_controller.dart`（聚合分页+筛选）
14. [ ] 移除原全局 `content_providers.dart` 中已下沉的 Provider
15. [ ] `flutter analyze` + `flutter test` 全量验证

### 第四批：前端 admin 状态下沉
16. [ ] 拆分 `admin_providers.dart`：按 Tab 拆分为 feature 内 Controller
17. [ ] 移除 `userActivityProvider`（已有 `profile_activity_controller` 替代）
18. [ ] `friendsProvider` 下沉至 `features/friends/application/`
19. [ ] 清理全局 `state/` 目录
20. [ ] `flutter analyze` + `flutter test` + golden test 全量验证
