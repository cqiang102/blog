-- 为 AI 会话表添加逻辑删除字段
ALTER TABLE ai_chat_sessions ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX idx_ai_sessions_user_deleted ON ai_chat_sessions(user_id, deleted) WHERE deleted = false;

-- 为 AI 消息表添加逻辑删除字段
ALTER TABLE ai_chat_messages ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX idx_ai_messages_session_deleted ON ai_chat_messages(session_id, deleted) WHERE deleted = false;
