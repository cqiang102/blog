# API 契约草案

统一前缀：`/api/v1`

统一响应：

```json
{
  "success": true,
  "data": {},
  "message": "ok"
}
```

## 认证

- `POST /auth/register`：邮箱注册。
- `POST /auth/login`：邮箱登录。
- `POST /auth/refresh`：刷新访问令牌。
- `GET /auth/providers`：返回可用第三方登录方式。
- `GET /oauth2/authorization/github`：Spring Security GitHub OAuth 入口。

## 内容

- `GET /contents/recommendations`：置顶、最新、点赞最多内容。
- `GET /contents`：分页搜索内容，支持 `query`、`tag`、`type`、`from`、`to`。
- `GET /contents/{id}`：内容详情。

## 互动

- `POST /contents/{contentId}/comments`：发表评论。
- `DELETE /comments/{commentId}`：删除自己的评论。
- `POST /contents/{contentId}/likes`：点赞。
- `DELETE /contents/{contentId}/likes`：取消点赞。
- `POST /contents/{contentId}/views`：记录浏览。

## 用户中心

- `GET /me`：当前用户资料。
- `PUT /me`：更新当前用户资料。
- `GET /me/comments`：我的评论。
- `GET /me/likes`：我的点赞。
- `GET /me/views`：我的浏览记录。

## AI

- `POST /ai/chat`：发送聊天消息。
- `GET /ai/quota`：查询每日剩余额度。

## 管理后台

管理员接口统一前缀：`/api/v1/admin`

- `GET /dashboard`：统计数据。
- `GET /logs`：日志监控。
- `CRUD /tags`
- `CRUD /contents`
- `CRUD /media`
- `CRUD /comments`
- `CRUD /views`
- `CRUD /likes`
- `CRUD /friends`
- `CRUD /users`
- `CRUD /ai/chats`
- `CRUD /knowledge`
