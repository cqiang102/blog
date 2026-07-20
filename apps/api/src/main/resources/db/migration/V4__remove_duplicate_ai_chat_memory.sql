-- AI conversation history is owned by ai_chat_messages. Keeping a second
-- framework-managed history caused partial/cancelled exchanges to diverge.
DROP TABLE IF EXISTS spring_ai_chat_memory;
