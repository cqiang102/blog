-- IVFFlat requires a sufficiently populated and trained index. When it is
-- created on an empty or very small table it can return no candidates at all.
-- HNSW has no training phase and keeps correct recall for a growing knowledge
-- base while still supporting cosine-distance nearest-neighbor queries.
DROP INDEX IF EXISTS idx_knowledge_chunks_embedding;

CREATE INDEX idx_knowledge_chunks_embedding
    ON knowledge_chunks
    USING hnsw (embedding vector_cosine_ops);

ALTER TABLE knowledge_chunks
    ADD CONSTRAINT knowledge_chunks_exactly_one_source
    CHECK ((doc_id IS NOT NULL) <> (content_id IS NOT NULL));
