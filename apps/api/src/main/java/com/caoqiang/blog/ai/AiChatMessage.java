package com.caoqiang.blog.ai;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * AI 聊天消息实体。
 * <p>
 * 对应数据库表 {@code ai_chat_messages}，记录 AI 对话中的一条消息。
 * 每条消息属于一个 {@link AiChatSession}，包含角色（用户/助手/工具/系统）、消息内容，
 * 以及可选的工具名称和 token 使用量统计。
 */
@Entity
@Table(name = "ai_chat_messages")
public class AiChatMessage {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 所属会话（懒加载） */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "session_id", nullable = false)
    private AiChatSession session;

    /** 消息角色：USER、ASSISTANT、TOOL、SYSTEM */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private AiMessageRole role;

    /** 消息正文内容 */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    /** 工具调用时的工具名称 */
    @Column(name = "tool_name", length = 120)
    private String toolName;

    /** 输入 token 数量 */
    @Column(name = "prompt_tokens")
    private Integer promptTokens;

    /** 输出 token 数量 */
    @Column(name = "completion_tokens")
    private Integer completionTokens;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected AiChatMessage() {
    }

    public AiChatMessage(AiChatSession session, AiMessageRole role, String content) {
        this.session = session;
        this.role = role;
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

    public AiChatSession getSession() {
        return session;
    }

    public AiMessageRole getRole() {
        return role;
    }

    public String getContent() {
        return content;
    }

    public String getToolName() {
        return toolName;
    }

    public Integer getPromptTokens() {
        return promptTokens;
    }

    public Integer getCompletionTokens() {
        return completionTokens;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
