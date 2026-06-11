-- 确保 SPRING_AI_CHAT_MEMORY 表有 sequence_id 列（Spring AI 2.0.0-RC2 要求）
-- 如果表已存在但缺少该列，则添加

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'spring_ai_chat_memory' AND column_name = 'sequence_id'
    ) THEN
        -- 添加 sequence_id 列
        ALTER TABLE SPRING_AI_CHAT_MEMORY ADD COLUMN sequence_id SERIAL;

        -- 重建主键（Spring AI 期望 (conversation_id, sequence_id) 作为主键）
        ALTER TABLE SPRING_AI_CHAT_MEMORY DROP CONSTRAINT IF EXISTS spring_ai_chat_memory_pkey;
        ALTER TABLE SPRING_AI_CHAT_MEMORY ADD PRIMARY KEY (conversation_id, sequence_id);
    END IF;
END $$;
