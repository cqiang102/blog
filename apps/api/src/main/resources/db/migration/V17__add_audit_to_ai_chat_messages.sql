ALTER TABLE ai_chat_messages ADD COLUMN audit_status VARCHAR(20);
ALTER TABLE ai_chat_messages ADD COLUMN audit_reason TEXT;
