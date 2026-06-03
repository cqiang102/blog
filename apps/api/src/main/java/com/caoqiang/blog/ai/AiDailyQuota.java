package com.caoqiang.blog.ai;

import com.caoqiang.blog.user.User;
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
import java.time.LocalDate;
import java.util.UUID;

/**
 * 每日 AI 配额实体。
 * <p>
 * 对应数据库表 {@code ai_daily_quotas}，记录用户每天的 AI 提问次数。
 * 每个用户每天一条记录，通过 {@link #increase()} 递增提问计数。
 * 配额限制逻辑在 {@link AiChatService} 中结合 Redis 缓存实现。
 */
@Entity
@Table(name = "ai_daily_quotas")
public class AiDailyQuota {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 所属用户（懒加载） */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

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

    public AiDailyQuota(User user, LocalDate quotaDate) {
        this.user = user;
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
}
