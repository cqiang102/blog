package com.caoqiang.blog.ai.knowledge.domain.repository;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeChunk;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
    List<Object[]> findSimilarChunks(
            @Param("queryEmbedding") String queryEmbedding,
            @Param("limit") int limit
    );

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
}
