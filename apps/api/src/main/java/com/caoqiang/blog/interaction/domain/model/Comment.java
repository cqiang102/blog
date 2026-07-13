package com.caoqiang.blog.interaction.domain.model;

import com.caoqiang.blog.shared.domain.model.AggregateRoot;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 评论实体
 * <p>
 * 表示用户对博客内容的评论。位于领域模型层，映射到数据库 comments 表。
 * </p>
 * <p>
 * 关键特性：
 * <ul>
 *   <li>支持评论审核状态管理（VISIBLE/PENDING/BLOCKED/DELETED）</li>
 *   <li>支持 AI 审核结果记录（auditStatus、auditReason）</li>
 *   <li>自动管理创建时间和更新时间</li>
 *   <li>与 Content 和 User 实体关联</li>
 * </ul>
 * </p>
 */
@Entity
@Table(name = "comments")
public class Comment extends AggregateRoot {

    /** 关联的内容 ID */
    @Column(name = "content_id", nullable = false)
    private UUID contentId;

    /** 评论作者 ID */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** 评论内容 */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    /** 评论状态，默认为 VISIBLE */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CommentStatus status = CommentStatus.VISIBLE;

    /** AI 审核状态（PASS/BLOCKED） */
    @Enumerated(EnumType.STRING)
    @Column(name = "audit_status", length = 20)
    private CommentStatus auditStatus;

    /** AI 审核原因 */
    @Column(name = "audit_reason", columnDefinition = "TEXT")
    private String auditReason;

    /** 创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** 更新时间 */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /**
     * JPA 受保护的无参构造函数
     */
    protected Comment() {
    }

    /**
     * 创建评论
     *
     * @param contentId 关联的内容 ID
     * @param userId    评论作者 ID
     * @param body    评论内容
     */
    public Comment(UUID contentId, UUID userId, String body) {
        this.contentId = contentId;
        this.userId = userId;
        this.body = body;
    }

    /**
     * 持久化前自动设置创建时间和更新时间
     */
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

    /**
     * 更新前自动设置更新时间
     */
    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * 标记评论为已删除（软删除）
     */
    public void markDeleted() {
        status = CommentStatus.DELETED;
    }

    /**
     * 设置评论状态
     *
     * @param status 新的评论状态
     */
    public void setStatus(CommentStatus status) {
        this.status = status;
    }

    /**
     * 判断评论是否可见
     *
     * @return 如果状态为 VISIBLE 则返回 true
     */
    public boolean isVisible() {
        return status == CommentStatus.VISIBLE;
    }

    /**
     * 判断评论是否待审核
     *
     * @return 如果状态为 PENDING 则返回 true
     */
    public boolean isPending() {
        return status == CommentStatus.PENDING;
    }

    /**
     * 判断评论是否被屏蔽
     *
     * @return 如果状态为 BLOCKED 则返回 true
     */
    public boolean isBlocked() {
        return status == CommentStatus.BLOCKED;
    }

    /**
     * 设置 AI 审核结果
     * <p>
     * 根据审核状态自动更新评论状态：BLOCKED 状态会屏蔽评论，其他状态设为可见。
     * </p>
     *
     * @param auditStatus 审核状态（PASS/BLOCKED）
     * @param auditReason 审核原因
     */
    public void setAuditResult(CommentStatus auditStatus, String auditReason) {
        this.auditStatus = auditStatus;
        this.auditReason = auditReason;
        if (status == CommentStatus.DELETED
                || (status == CommentStatus.BLOCKED && auditStatus != CommentStatus.BLOCKED)) {
            return;
        }
        if (auditStatus == CommentStatus.BLOCKED) {
            this.status = CommentStatus.BLOCKED;
        } else {
            this.status = CommentStatus.VISIBLE;
        }
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getBody() {
        return body;
    }

    public CommentStatus getStatus() {
        return status;
    }

    public CommentStatus getAuditStatus() {
        return auditStatus;
    }

    public String getAuditReason() {
        return auditReason;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
