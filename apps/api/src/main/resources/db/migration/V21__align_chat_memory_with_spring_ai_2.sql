-- Spring AI 2.0 GA PostgreSQL ChatMemory schema uses TIMESTAMPTZ and BIGINT.
-- Alter the existing columns in place so persisted conversation history is kept.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'spring_ai_chat_memory'
          AND column_name = 'timestamp'
          AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE spring_ai_chat_memory
            ALTER COLUMN "timestamp" TYPE TIMESTAMP WITH TIME ZONE
            USING "timestamp" AT TIME ZONE current_setting('TIMEZONE');
    END IF;
END $$;

ALTER TABLE spring_ai_chat_memory
    ALTER COLUMN sequence_id TYPE BIGINT;

CREATE INDEX IF NOT EXISTS spring_ai_chat_memory_conversation_id_timestamp_idx
    ON spring_ai_chat_memory (conversation_id, "timestamp");
