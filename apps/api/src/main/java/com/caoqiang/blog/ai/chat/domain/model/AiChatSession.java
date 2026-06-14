package com.caoqiang.blog.ai.chat.domain.model;

import com.caoqiang.blog.user.domain.model.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * AI 聊天会话实体。
 * <p>
 * 对应数据库表 {@code ai_chat_sessions}，记录用户与 AI 的一次对话会话。
 * 每个会话关联一个用户，包含标题、创建时间和更新时间。
 * 会话通过 {@link AiChatMessage} 存储具体的消息记录。
 */
@Entity
@Table(name = "ai_chat_sessions")
public class AiChatSession {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 所属用户（懒加载） */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** 会话标题，最大 160 字符 */
    @Column(length = 160)
    private String title;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** 是否已删除（逻辑删除） */
    @Column(nullable = false)
    private boolean deleted = false;

    protected AiChatSession() {
    }

    public AiChatSession(User user, String title) {
        this.user = user;
        this.title = title;
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

    /** 标记会话为已删除（逻辑删除） */
    public void markDeleted() {
        this.deleted = true;
    }

    public void touch() {
        this.updatedAt = Instant.now();
    }

    public UUID getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public String getTitle() {
        return title;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public boolean isDeleted() {
        return deleted;
    }
}
