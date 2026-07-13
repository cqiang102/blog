package com.caoqiang.blog.ai.chat.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

/**
 * 每日 AI 配额实体。
 * <p>
 * 对应数据库表 {@code ai_daily_quotas}，记录用户每天的 AI 提问次数。
 * 每个用户每天一条记录，通过 {@link #increase()} 递增提问计数。
 * 配额限制逻辑在 {@link com.caoqiang.blog.ai.chat.application.service.AiChatService} 中结合 Redis 缓存实现。
 */
@Entity
@Table(name = "ai_daily_quotas")
public class AiDailyQuota {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 所属用户 ID */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** 配额日期（UTC） */
    @Column(name = "quota_date", nullable = false)
    private LocalDate quotaDate;

    /** 当日已提问次数 */
    @Column(name = "question_count", nullable = false)
    private int questionCount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected AiDailyQuota() {
    }

    public AiDailyQuota(UUID userId, LocalDate quotaDate) {
        this.userId = userId;
        this.quotaDate = quotaDate;
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

    /** 将当日提问次数加 1。 */
    public void increase() {
        questionCount += 1;
    }

    public int getQuestionCount() {
        return questionCount;
    }

    public UUID getUserId() {
        return userId;
    }

    public LocalDate getQuotaDate() {
        return quotaDate;
    }
}
