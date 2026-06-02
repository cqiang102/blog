-- 添加 content_id 字段到 knowledge_chunks 表，用于索引系统内容
ALTER TABLE knowledge_chunks ADD COLUMN content_id UUID REFERENCES contents(id) ON DELETE CASCADE;

-- 修改 doc_id 为可空（因为现在可以是 content_id 或 doc_id）
ALTER TABLE knowledge_chunks ALTER COLUMN doc_id DROP NOT NULL;

-- 添加索引
CREATE INDEX idx_knowledge_chunks_content_id ON knowledge_chunks(content_id);
