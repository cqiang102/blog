-- Spring AI JDBC Chat Memory table
CREATE TABLE IF NOT EXISTS SPRING_AI_CHAT_MEMORY (
    conversation_id VARCHAR(256) NOT NULL,
    message_index INT NOT NULL,
    message_content TEXT NOT NULL,
    message_type VARCHAR(64) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, message_index)
);

CREATE INDEX IF NOT EXISTS idx_chat_memory_conversation_id ON SPRING_AI_CHAT_MEMORY(conversation_id);
