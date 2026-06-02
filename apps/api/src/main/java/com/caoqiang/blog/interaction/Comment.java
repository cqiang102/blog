package com.caoqiang.blog.interaction;

import com.caoqiang.blog.content.Content;
import com.caoqiang.blog.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "comments")
public class Comment {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "content_id", nullable = false)
    private Content content;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String body;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CommentStatus status = CommentStatus.VISIBLE;

    @Column(name = "audit_status", length = 20)
    private String auditStatus;

    @Column(name = "audit_reason", columnDefinition = "TEXT")
    private String auditReason;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Comment() {
    }

    public Comment(Content content, User user, String body) {
        this.content = content;
        this.user = user;
        this.body = body;
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

    public void markDeleted() {
        status = CommentStatus.DELETED;
    }

    public void setStatus(CommentStatus status) {
        this.status = status;
    }

    public boolean isVisible() {
        return status == CommentStatus.VISIBLE;
    }

    public boolean isPending() {
        return status == CommentStatus.PENDING;
    }

    public boolean isBlocked() {
        return status == CommentStatus.BLOCKED;
    }

    public void setAuditResult(String auditStatus, String auditReason) {
        this.auditStatus = auditStatus;
        this.auditReason = auditReason;
        if ("BLOCKED".equals(auditStatus)) {
            this.status = CommentStatus.BLOCKED;
        } else {
            this.status = CommentStatus.VISIBLE;
        }
    }

    public UUID getId() {
        return id;
    }

    public Content getContent() {
        return content;
    }

    public User getUser() {
        return user;
    }

    public String getBody() {
        return body;
    }

    public CommentStatus getStatus() {
        return status;
    }

    public String getAuditStatus() {
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
