package com.caoqiang.blog.ai;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface KnowledgeChunkRepository extends JpaRepository<KnowledgeChunk, UUID> {

    @Query(value = """
            SELECT kc.id, kc.doc_id, kc.chunk_index, kc.content, kc.metadata,
                   1 - (kc.embedding <=> :queryEmbedding::vector) AS score
            FROM knowledge_chunks kc
            JOIN knowledge_docs kd ON kc.doc_id = kd.id
            WHERE kd.enabled = true
            ORDER BY kc.embedding <=> :queryEmbedding::vector
            LIMIT :limit
            """, nativeQuery = true)
    List<Object[]> findSimilarChunks(
            @Param("queryEmbedding") String queryEmbedding,
            @Param("limit") int limit
    );

    List<KnowledgeChunk> findByDocIdOrderByChunkIndex(UUID docId);

    void deleteByDocId(UUID docId);
}
