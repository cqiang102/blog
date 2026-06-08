package com.caoqiang.blog.ai.knowledge.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 知识文档实体。
 * <p>
 * 对应数据库表 {@code knowledge_docs}，存储知识库中的文档信息。
 * 文档可以是手动输入、URL 抓取、文件上传或从博客内容导入。
 * 文档正文通过 {@link KnowledgeIndexService} 分块并生成向量索引，
 * 供 AI 聊天时进行语义搜索。
 */
@Entity
@Table(name = "knowledge_docs")
public class KnowledgeDoc {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 文档标题 */
    @Column(nullable = false, length = 180)
    private String title;

    /** 来源类型：MANUAL、URL、FILE、CONTENT */
    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", nullable = false, length = 40)
    private KnowledgeSourceType sourceType = KnowledgeSourceType.MANUAL;

    /** 来源引用（如 URL 地址、文件路径等） */
    @Column(name = "source_ref", columnDefinition = "TEXT")
    private String sourceRef;

    /** 文档正文内容 */
    @Column(columnDefinition = "TEXT")
    private String body;

    /** 是否启用（禁用后不参与向量搜索） */
    @Column(nullable = false)
    private boolean enabled = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected KnowledgeDoc() {
    }

    public KnowledgeDoc(
            String title,
            KnowledgeSourceType sourceType,
            String sourceRef,
            String body,
            boolean enabled
    ) {
        apply(title, sourceType, sourceRef, body, enabled);
    }

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * 应用文档属性更新（标题会自动去除首尾空白）。
     *
     * @param title      文档标题
     * @param sourceType 来源类型
     * @param sourceRef  来源引用
     * @param body       文档正文
     * @param enabled    是否启用
     */
    public void apply(
            String title,
            KnowledgeSourceType sourceType,
            String sourceRef,
            String body,
            boolean enabled
    ) {
        this.title = title.trim();
        this.sourceType = sourceType;
        this.sourceRef = sourceRef;
        this.body = body;
        this.enabled = enabled;
    }

    public UUID getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public KnowledgeSourceType getSourceType() {
        return sourceType;
    }

    public String getSourceRef() {
        return sourceRef;
    }

    public String getBody() {
        return body;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
