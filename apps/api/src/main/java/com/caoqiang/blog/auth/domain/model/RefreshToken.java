package com.caoqiang.blog.auth.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 刷新令牌实体
 * 映射数据库中的 refresh_tokens 表，存储刷新令牌的哈希值和元数据。
 * 位于博客系统的认证模块，是令牌持久化的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>令牌存储 - 存储令牌的哈希值，不存储原始令牌</li>
 *   <li>用户关联 - 通过外键关联到用户实体</li>
 *   <li>生命周期管理 - 包含创建时间、过期时间和撤销时间</li>
 *   <li>令牌轮换 - 支持令牌撤销，实现令牌轮换机制</li>
 *   <li>令牌族 - 通过 familyId 关联同一登录链的所有令牌，支持重放攻击检测与族撤销</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

    /** 主键，UUID 类型，自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 关联用户 ID；认证领域不直接持有用户模块的 JPA 实体。 */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** 令牌族 ID：同一次登录链的所有令牌共享此 ID，用于重放攻击检测与族撤销。 */
    @Column(name = "family_id")
    private UUID familyId;

    /** 令牌的 SHA-256 哈希值 */
    @Column(name = "token_hash", nullable = false, columnDefinition = "TEXT")
    private String tokenHash;

    /** 令牌过期时间 */
    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    /** 令牌撤销时间，null 表示未撤销 */
    @Column(name = "revoked_at")
    private Instant revokedAt;

    /** 记录创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * 默认构造函数，供 JPA 使用
     */
    protected RefreshToken() {}

    /**
     * 构造函数，创建新的刷新令牌（新登录链，自动生成 familyId）
     *
     * @param userId    关联用户 ID
     * @param tokenHash 令牌的哈希值
     * @param expiresAt 过期时间
     */
    public RefreshToken(UUID userId, String tokenHash, Instant expiresAt) {
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
        this.familyId = UUID.randomUUID();
    }

    /**
     * 构造函数，在已有令牌族内创建轮换令牌
     *
     * @param userId    关联用户 ID
     * @param tokenHash 令牌的哈希值
     * @param expiresAt 过期时间
     * @param familyId  所属令牌族 ID
     */
    public RefreshToken(UUID userId, String tokenHash, Instant expiresAt, UUID familyId) {
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
        this.familyId = familyId;
    }

    /**
     * JPA 生命周期回调：在持久化之前设置创建时间
     */
    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    /**
     * 获取关联用户 ID
     *
     * @return 用户 ID
     */
    public UUID getUserId() {
        return userId;
    }

    /**
     * 获取令牌族 ID
     *
     * @return 令牌族 ID
     */
    public UUID getFamilyId() {
        return familyId;
    }

    /**
     * 获取令牌过期时间
     *
     * @return 过期时间
     */
    public Instant getExpiresAt() {
        return expiresAt;
    }

    /**
     * 获取令牌撤销时间
     *
     * @return 撤销时间，null 表示未撤销
     */
    public Instant getRevokedAt() {
        return revokedAt;
    }

    /**
     * 判断令牌是否已被撤销
     */
    public boolean isRevoked() {
        return revokedAt != null;
    }

    /**
     * 撤销令牌
     * 设置令牌的撤销时间，标记令牌为已撤销状态。
     *
     * @param revokedAt 撤销时间
     */
    public void revoke(Instant revokedAt) {
        this.revokedAt = revokedAt;
    }

    /**
     * 检查令牌是否已过期
     *
     * @param now 当前时间
     * @return 如果令牌已过期返回 true，否则返回 false
     */
    public boolean isExpired(Instant now) {
        return !expiresAt.isAfter(now);
    }
}
