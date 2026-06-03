-- V8: 切换 embedding 模型为 nomic-embed-text (768 维)
-- 原模型: text-embedding-3-small (1536 维)

-- 删除旧索引
DROP INDEX IF EXISTS idx_knowledge_chunks_embedding;

-- 清空旧向量数据（维度不兼容，需要重新生成）
UPDATE knowledge_chunks SET embedding = NULL;

-- 修改列维度
ALTER TABLE knowledge_chunks ALTER COLUMN embedding TYPE vector(768);

-- 重建索引
CREATE INDEX idx_knowledge_chunks_embedding
  ON knowledge_chunks USING ivfflat (embedding vector_cosine_ops);
