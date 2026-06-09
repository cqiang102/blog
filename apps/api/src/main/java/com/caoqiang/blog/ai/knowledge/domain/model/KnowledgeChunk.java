package com.caoqiang.blog.ai.knowledge.domain.model;

import com.caoqiang.blog.shared.persistence.PgJsonbType;
import com.caoqiang.blog.shared.persistence.PgVectorType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import org.hibernate.annotations.Type;

/**
 * 知识分块实体（含向量嵌入）。
 * <p>
 * 对应数据库表 {@code knowledge_chunks}，存储文档或博客内容经过分块和向量嵌入后的数据。
 * 每个分块包含原始文本内容和 768 维的向量表示，用于语义相似度搜索。
 * <p>
 * 分块来源有两种：
 * <ul>
 *   <li>知识文档：通过 {@code doc_id} 关联 {@link KnowledgeDoc}</li>
 *   <li>博客内容：通过 {@code content_id} 关联博客内容</li>
 * </ul>
 */
@Entity
@Table(name = "knowledge_chunks")
public class KnowledgeChunk {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 关联的知识文档（可为空，博客内容分块时为 null） */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "doc_id")
    private KnowledgeDoc doc;

    /** 关联的博客内容 ID（可为空，知识文档分块时为 null） */
    @Column(name = "content_id")
    private UUID contentId;

    /** 分块在文档中的序号（从 0 开始） */
    @Column(name = "chunk_index", nullable = false)
    private int chunkIndex;

    /** 分块的文本内容 */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /** 768 维向量嵌入，用于余弦相似度搜索 */
    @Type(PgVectorType.class)
    @Column(columnDefinition = "VECTOR(768)")
    private String embedding;

    /** 元数据（JSON 格式，如错误信息等） */
    @Type(PgJsonbType.class)
    @Column(columnDefinition = "JSONB")
    private String metadata;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected KnowledgeChunk() {
    }

    public KnowledgeChunk(KnowledgeDoc doc, int chunkIndex, String content) {
        this.doc = doc;
        this.chunkIndex = chunkIndex;
        this.content = content;
    }

    public KnowledgeChunk(UUID contentId, int chunkIndex, String content) {
        this.contentId = contentId;
        this.chunkIndex = chunkIndex;
        this.content = content;
    }

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public KnowledgeDoc getDoc() {
        return doc;
    }

    public UUID getContentId() {
        return contentId;
    }

    public int getChunkIndex() {
        return chunkIndex;
    }

    public String getContent() {
        return content;
    }

    public String getEmbedding() {
        return embedding;
    }

    public void setEmbedding(String embedding) {
        this.embedding = embedding;
    }

    public String getMetadata() {
        return metadata;
    }

    public void setMetadata(String metadata) {
        this.metadata = metadata;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
