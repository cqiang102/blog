-- Remove any legacy duplicate content chunks before enforcing the invariant.
WITH duplicate_content_chunks AS (
    SELECT id,
           row_number() OVER (
               PARTITION BY content_id, chunk_index
               ORDER BY created_at DESC, id DESC
           ) AS duplicate_rank
    FROM knowledge_chunks
    WHERE content_id IS NOT NULL
)
DELETE FROM knowledge_chunks chunk
USING duplicate_content_chunks duplicate
WHERE chunk.id = duplicate.id
  AND duplicate.duplicate_rank > 1;

-- The original nullable UNIQUE(doc_id, chunk_index) cannot protect content chunks.
ALTER TABLE knowledge_chunks
    DROP CONSTRAINT IF EXISTS knowledge_chunks_doc_id_chunk_index_key;

CREATE UNIQUE INDEX ux_knowledge_chunks_doc_chunk
    ON knowledge_chunks(doc_id, chunk_index)
    WHERE doc_id IS NOT NULL;

CREATE UNIQUE INDEX ux_knowledge_chunks_content_chunk
    ON knowledge_chunks(content_id, chunk_index)
    WHERE content_id IS NOT NULL;

-- Refresh-token lookup and rotation always use the token hash.
CREATE UNIQUE INDEX ux_refresh_tokens_token_hash
    ON refresh_tokens(token_hash);
