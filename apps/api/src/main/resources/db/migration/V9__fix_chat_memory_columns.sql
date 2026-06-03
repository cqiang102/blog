-- 修复 Spring AI 2.0.0-M8 Chat Memory 表列名
-- Spring AI 期望的列名是 content 和 type，而不是 message_content 和 message_type

ALTER TABLE SPRING_AI_CHAT_MEMORY RENAME COLUMN message_content TO content;
ALTER TABLE SPRING_AI_CHAT_MEMORY RENAME COLUMN message_type TO type;
