# API 契约概览

业务 REST 接口统一使用 `/api/v1` 前缀，统一响应为：

```json
{
  "success": true,
  "data": {},
  "message": "ok"
}
```

本文档只维护资源边界。完整请求参数、响应字段和状态码以运行时 OpenAPI 为准：

- Swagger UI：`http://localhost:8080/swagger-ui.html`
- OpenAPI JSON：`http://localhost:8080/v3/api-docs`

## 公开与认证

- `/auth`：验证码、注册、登录、刷新令牌、浏览器绑定的 OAuth 回调和登录方式查询。
- `/auth/github`：GitHub 账号绑定。
- `/contents`：推荐、分页搜索、详情和标签。
- `/media-assets/{id}/file`：媒体文件。
- `/friends/random`：随机可见友链。
- `/contents/{contentId}/comments`：评论列表与新增评论。
- `/contents/{contentId}/likes`：点赞与取消点赞。
- `/contents/{contentId}/views`：记录浏览。
- `/comments/{commentId}`：删除自己的评论。

## 用户中心

- `/me`：资料查询和更新。
- `/me/avatar`：头像上传。
- `/me/password`：修改或首次设置密码。
- `/me/oauth-accounts`：OAuth 账号查询和解绑。
- `/me/comments`、`/me/likes`、`/me/views`：个人互动记录及删除。

## AI

- `/ai/chat`：同步聊天。
- `/ai/chat/stream`：SSE 流式聊天。
- `/ai/quota`：每日配额。
- `/ai/sessions`：创建、查询和删除会话。
- `/ai/sessions/{sessionId}/messages`：会话消息。

## 管理后台

管理员接口统一使用 `/admin` 子路径：

- `/admin/dashboard`、`/admin/modules`、`/admin/logs`
- `/admin/contents`、`/admin/tags`、`/admin/media-assets`
- `/admin/comments`、`/admin/likes`、`/admin/views`
- `/admin/friends`、`/admin/users`
- `/admin/ai/chats`
- `/admin/knowledge/docs`
