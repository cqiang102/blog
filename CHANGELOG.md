# Changelog

## 1.0.0 - 2026-06-24

### Added

- 首个可部署发布版本，包含 Flutter Web 前端、Spring Boot API、PostgreSQL/Redis/MinIO 生产编排。
- 生产部署包默认输出为 `blog-mimo-1.0.0.tar.gz`，解压目录保持 `blog-deploy/`。
- `.data/postgres`、`.data/redis`、`.data/minio` 与 `docker-compose.yml` 同级持久化运行数据。

### Changed

- API 部署从 native image 改为 Java 21 JRE + Spring Boot 可执行 JAR。
- Flyway 历史合并为 `V1__init_schema.sql` 和 `V2__seed_initial_data.sql`，适用于全新数据库部署。
- 媒体文件引用改为稳定路径，避免数据库持久化 Docker 内部 MinIO URL。

### Fixed

- Redis 缓存序列化在 JDK 集合类型下的反序列化问题。
- 429/401 过滤器直接响应中文消息时的 UTF-8 编码问题。
- Flutter API 客户端拼接路径时的重复斜杠问题。

### Notes

- 该版本是新库部署版；旧 PostgreSQL 数据目录不能直接复用到合并后的 Flyway 迁移集。
- 生产上线前需要填写 `.env` 中的数据库、Redis、MinIO、JWT、GitHub OAuth、SMTP、OpenAI/Ollama 配置，并完成真实域名 HTTPS 冒烟。
