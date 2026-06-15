# 文档索引

## 当前文档

| 文档 | 用途 | 维护原则 |
|------|------|----------|
| [架构说明](architecture.md) | 目录边界、模块职责、命名约定、重构顺序 | 结构调整时同步更新 |
| [功能清单](features.md) | 已实现能力与待扩展方向 | 以代码和测试为准 |
| [需求说明](requirements.md) | 产品目标、角色和核心能力 | 产品范围变化时更新 |
| [API 契约概览](api-contract.md) | 主要端点导航 | 完整字段以 OpenAPI 为准 |
| [运行手册](runbook.md) | 本地启动、profile、诊断与故障排查 | 命令变化时更新 |
| [版本升级说明](upgrade-spring-boot-4.1-spring-ai-2.0.md) | Boot 4.1 与 Spring AI 2.0 兼容性和验证记录 | 框架升级时更新 |
| [部署说明](deployment.md) | 生产部署、备份、监控和回滚 | 基础设施变化时更新 |

## 历史资料

| 文档 | 状态 |
|------|------|
| [初始开发计划](development-plan.md) | 阶段目标已基本完成，仅保留决策背景 |
| [UI 改版方案](ui-redesign-plan.md) | 主要方案已落地，仅保留设计依据 |

## 信息来源

发生冲突时，按以下优先级判断：

1. 自动化测试和实际运行行为
2. 后端 OpenAPI、数据库迁移和配置文件
3. `architecture.md`、`runbook.md`、`deployment.md`
4. 功能清单和历史计划
