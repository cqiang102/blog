package com.caoqiang.blog.ai.knowledge.domain.repository;

import com.caoqiang.blog.ai.knowledge.domain.model.FailedEmbeddingChunk;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeChunk;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

/**
 * 知识分块 Repository（含向量相似度查询）。
 * <p>
 * 提供知识分块的 CRUD 操作，核心能力是基于 PostgreSQL pgvector 扩展的
 * 余弦相似度搜索（{@code <=>} 运算符），用于 AI 聊天时的语义检索。
 * <p>
 * 向量搜索会自动过滤：
 * <ul>
 *   <li>已禁用的知识文档分块</li>
 *   <li>未发布的博客内容分块</li>
 *   <li>没有向量嵌入的分块</li>
 * </ul>
 */
public interface KnowledgeChunkRepository extends JpaRepository<KnowledgeChunk, UUID> {

    /**
     * 基于向量余弦相似度搜索最相关的知识分块。
     * <p>
     * 使用 PostgreSQL pgvector 的 {@code <=>} 运算符计算余弦距离，
     * 返回相似度分数（1 - 距离）最高的 limit 条记录。
     *
     * @param queryEmbedding 查询向量的字符串表示（如 "[0.1,0.2,...]"）
     * @param limit          返回结果数量上限
     * @return 包含 id, doc_id, content_id, chunk_index, content, metadata, score 的结果数组
     */
    @Query(value = """
            SELECT kc.id, kc.doc_id, kc.content_id, kc.chunk_index, kc.content, kc.metadata,
                   1 - (kc.embedding <=> CAST(:queryEmbedding AS vector)) AS score
            FROM knowledge_chunks kc
            WHERE kc.embedding IS NOT NULL
              AND (
                    (kc.doc_id IS NOT NULL AND EXISTS (
                        SELECT 1 FROM knowledge_docs kd WHERE kd.id = kc.doc_id AND kd.enabled = true))
                 OR (kc.content_id IS NOT NULL AND EXISTS (
                        SELECT 1 FROM contents c WHERE c.id = kc.content_id AND c.status = 'PUBLISHED' AND c.deleted_at IS NULL))
              )
            ORDER BY kc.embedding <=> CAST(:queryEmbedding AS vector)
            LIMIT :limit
            """, nativeQuery = true)
    @Transactional(readOnly = true)
    List<Object[]> findSimilarChunks(@Param("queryEmbedding") String queryEmbedding, @Param("limit") int limit);

    /**
     * 获取指定文档的所有分块，按分块序号正序排列。
     *
     * @param docId 文档 ID
     * @return 分块列表
     */
    List<KnowledgeChunk> findByDocIdOrderByChunkIndex(UUID docId);

    /**
     * 删除指定文档的所有分块。
     * <p>
     * 使用 {@code @Modifying @Query} 直接执行 DELETE SQL，
     * 避免派生删除（derived delete）延迟 flush 导致的唯一约束冲突。
     *
     * @param docId 文档 ID
     */
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM KnowledgeChunk k WHERE k.doc.id = :docId")
    void deleteByDocId(@Param("docId") UUID docId);

    /**
     * 删除指定博客内容的所有分块。
     * <p>
     * 使用 {@code @Modifying @Query} 直接执行 DELETE SQL，
     * 避免派生删除（derived delete）延迟 flush 导致的唯一约束冲突。
     *
     * @param contentId 博客内容 ID
     */
    @Modifying(flushAutomatically = true)
    @Query("DELETE FROM KnowledgeChunk k WHERE k.contentId = :contentId")
    void deleteByContentId(@Param("contentId") UUID contentId);

    @Query(value = """
                    SELECT id AS id, content AS content
                    FROM knowledge_chunks
                    WHERE metadata::text LIKE '%embedding_generation_failed%'
                    ORDER BY id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<FailedEmbeddingChunk> findFailedEmbeddingCandidates(@Param("limit") int limit);

    /**
     * Returns the oldest failed embeddings first. Updating the failure timestamp after a retry
     * moves that chunk behind failures which have not been attempted recently, so a permanently
     * failing first page cannot starve later chunks.
     */
    @Query(value = """
                    SELECT id AS id, content AS content
                    FROM knowledge_chunks
                    WHERE metadata::text LIKE '%embedding_generation_failed%'
                    ORDER BY COALESCE(metadata ->> 'timestamp', ''), id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<FailedEmbeddingChunk> findFailedEmbeddingCandidatesForScheduledRetry(@Param("limit") int limit);

    @Query(value = """
                    SELECT id AS id, content AS content
                    FROM knowledge_chunks
                    WHERE metadata::text LIKE '%embedding_generation_failed%'
                      AND id > :afterId
                    ORDER BY id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<FailedEmbeddingChunk> findFailedEmbeddingCandidatesAfter(
            @Param("afterId") UUID afterId, @Param("limit") int limit);

    /** Finds enabled documents whose latest durable source revision has no corresponding chunks. */
    @Query(value = """
                    SELECT document.id
                    FROM knowledge_docs document
                    WHERE document.enabled = true
                      AND COALESCE(BTRIM(document.body), '') <> ''
                      AND NOT EXISTS (
                          SELECT 1
                          FROM knowledge_chunks chunk
                          WHERE chunk.doc_id = document.id
                            AND chunk.created_at >= document.updated_at
                      )
                    ORDER BY document.updated_at, document.id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<UUID> findDocumentIdsNeedingIndex(@Param("limit") int limit);

    /** Finds documents whose chunks must be removed because the source is disabled or empty. */
    @Query(value = """
                    SELECT document.id
                    FROM knowledge_docs document
                    WHERE (document.enabled = false OR COALESCE(BTRIM(document.body), '') = '')
                      AND EXISTS (
                          SELECT 1 FROM knowledge_chunks chunk WHERE chunk.doc_id = document.id
                      )
                    ORDER BY document.updated_at, document.id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<UUID> findDocumentIdsNeedingIndexDeletion(@Param("limit") int limit);

    /** Finds published contents whose latest durable source revision has no corresponding chunks. */
    @Query(value = """
                    SELECT content.id
                    FROM contents content
                    WHERE content.status = 'PUBLISHED'
                      AND content.deleted_at IS NULL
                      AND NOT EXISTS (
                          SELECT 1
                          FROM knowledge_chunks chunk
                          WHERE chunk.content_id = content.id
                            AND chunk.created_at >= content.updated_at
                      )
                    ORDER BY content.updated_at, content.id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<UUID> findContentIdsNeedingIndex(@Param("limit") int limit);

    /** Finds chunks whose content is no longer published and therefore must be removed. */
    @Query(value = """
                    SELECT content.id
                    FROM contents content
                    WHERE (content.status <> 'PUBLISHED' OR content.deleted_at IS NOT NULL)
                      AND EXISTS (
                          SELECT 1 FROM knowledge_chunks chunk WHERE chunk.content_id = content.id
                      )
                    ORDER BY content.updated_at, content.id
                    LIMIT :limit
                    """, nativeQuery = true)
    List<UUID> findContentIdsNeedingIndexDeletion(@Param("limit") int limit);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
                    UPDATE knowledge_chunks
                    SET embedding = CAST(:embedding AS vector), metadata = NULL
                    WHERE id = :id
                      AND content = :expectedContent
                      AND metadata::text LIKE '%embedding_generation_failed%'
                    """, nativeQuery = true)
    int updateEmbeddingIfContentMatches(
            @Param("id") UUID id,
            @Param("expectedContent") String expectedContent,
            @Param("embedding") String embedding);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = """
                    UPDATE knowledge_chunks
                    SET metadata = CAST(:metadata AS jsonb)
                    WHERE id = :id
                      AND content = :expectedContent
                      AND metadata::text LIKE '%embedding_generation_failed%'
                    """, nativeQuery = true)
    int updateEmbeddingFailureIfContentMatches(
            @Param("id") UUID id, @Param("expectedContent") String expectedContent, @Param("metadata") String metadata);

    /**
     * 统计总分块数。
     *
     * @return 总分块数
     */
    @Query(value = "SELECT COUNT(*) FROM knowledge_chunks", nativeQuery = true)
    long countAll();

    /**
     * 统计有向量嵌入的分块数。
     *
     * @return 有向量的分块数
     */
    @Query(value = "SELECT COUNT(*) FROM knowledge_chunks WHERE embedding IS NOT NULL", nativeQuery = true)
    long countWithEmbedding();

    /**
     * 统计嵌入失败的分块数。
     *
     * @return 嵌入失败的分块数
     */
    @Query(
            value = "SELECT COUNT(*) FROM knowledge_chunks WHERE metadata::text LIKE '%embedding_generation_failed%'",
            nativeQuery = true)
    long countWithFailedEmbedding();
}
