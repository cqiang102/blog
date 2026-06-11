-- 重建 SPRING_AI_CHAT_MEMORY 表，匹配 Spring AI JdbcChatMemoryRepository 期望的 schema
-- 列: conversation_id, content, type, timestamp, sequence_id

CREATE TABLE IF NOT EXISTS SPRING_AI_CHAT_MEMORY (
    conversation_id VARCHAR(256) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(64) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sequence_id SERIAL,
    PRIMARY KEY (conversation_id, sequence_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_memory_conversation_id ON SPRING_AI_CHAT_MEMORY(conversation_id);
