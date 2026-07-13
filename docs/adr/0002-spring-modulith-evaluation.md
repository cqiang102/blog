# ADR-0002：暂缓引入 Spring Modulith

- 状态：已接受
- 日期：2026-07-13
- 复审条件：content 与 interaction 的双向模块依赖被消除，或需要模块切片集成测试/运行时模块观测

## 背景

当前后端已经按 `admin`、`ai`、`audit`、`auth`、`content`、`friend`、`interaction`、`user` 组织为模块化单体，并通过 ArchUnit 验证领域层、应用层和跨模块公开 API 边界。

Spring Modulith 2.1 的官方验证能力包括：

- 模块依赖图不得出现环；
- 跨模块只能访问模块公开接口；
- 可选地声明 `allowedDependencies`；
- 通过 `@ApplicationModuleTest` 对单个模块及其依赖做切片集成测试。

参考：

- [Verifying Application Module Structure](https://docs.spring.io/spring-modulith/reference/verification.html)
- [Integration Testing Application Modules](https://docs.spring.io/spring-modulith/reference/testing.html)
- [ApplicationModule API](https://docs.spring.io/spring-modulith/docs/current/api/org/springframework/modulith/ApplicationModule.html)

## 方案比较

| 方案 | 收益 | 代价与限制 | 结论 |
|---|---|---|---|
| 继续使用 ArchUnit | 与现有 `application/api`、公开事件和反向端口约定完全匹配；规则可逐步收紧 | 模块清单和依赖声明需要自行维护 | 当前采用 |
| 仅测试期引入 Spring Modulith | 自动发现模块、验证无环、提供模块切片测试 | 需要为 `application/api`、`event`、`application/port` 声明 named interfaces；当前模块图存在环 | 满足前置条件后优先采用 |
| 引入运行时支持 | 可做启动期验证、模块初始化排序和运行时观测 | 增加运行时依赖与运维面，目前没有对应需求 | 暂不采用 |

## 关键发现

当前存在一条明确的双向协作：

```text
interaction -> content
  发布状态校验、互动计数更新、内容标题快照

content -> interaction
  当前用户点赞状态、点赞事件触发的缓存一致性
```

现有 ArchUnit 会阻止双方访问内部实现，但允许通过公开 API 和公开事件协作。Spring Modulith 的无环验证会拒绝整个模块级环；在没有先改变数据所有权或引入独立组合模块前，加入依赖只会产生需要忽略的违规，降低门禁可信度。

## 决策

本阶段不加入 Spring Modulith 依赖，继续使用 ArchUnit 作为强制门禁，并补充以下保障：

1. 通用规则禁止业务模块访问其他模块的 domain、内部 service/DTO 和 infrastructure；
2. 公开 `application/api` 服务必须有直接契约测试；
3. PostgreSQL/Testcontainers 测试继续验证跨模块标量外键与迁移后的持久化行为；
4. 不为满足工具而添加违规忽略列表。

## 后续采用路径

满足以下条件后，先以 test scope 引入 Spring Modulith：

1. 消除 `content ↔ interaction` 模块环，例如将详情组合移入独立查询/接口组合模块，并让互动计数缓存失效由 content 自身完成；
2. 为 `application/api`、公开事件和必要反向端口声明 named interfaces；
3. 使用 `ApplicationModules.of(BlogApiApplication.class).verify()` 与现有 ArchUnit 并行运行；
4. 选择一个高价值模块试点 `@ApplicationModuleTest`，验证收益后再扩大范围；
5. 只有出现启动顺序或模块级运行时观测需求时，才引入 runtime 支持。
