-- 删除旧的 chat memory 表，让 Spring AI 自动创建正确的 schema
DROP TABLE IF EXISTS SPRING_AI_CHAT_MEMORY CASCADE;
DROP INDEX IF EXISTS idx_chat_memory_conversation_id;
