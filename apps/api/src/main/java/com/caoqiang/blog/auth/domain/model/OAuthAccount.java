package com.caoqiang.blog.auth.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * OAuth 账户关联实体
 * 映射数据库中的 oauth_accounts 表，存储本地用户与第三方 OAuth 账户的关联关系。
 * 位于博客系统的认证模块，是多账户登录的核心数据模型。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>账户关联 - 将本地用户与第三方 OAuth 账户关联</li>
 *   <li>多提供者支持 - 支持多个 OAuth 提供者（如 GitHub、QQ 等）</li>
 *   <li>用户信息存储 - 存储第三方平台的用户 ID 和用户名</li>
 *   <li>时间戳记录 - 记录关联创建时间</li>
 * </ul>
 *
 * <p>数据库表结构：</p>
 * <ul>
 *   <li>id - 主键，UUID 类型</li>
 *   <li>user_id - 外键，关联用户表</li>
 *   <li>provider - OAuth 提供者枚举</li>
 *   <li>provider_user_id - 第三方平台的用户 ID</li>
 *   <li>provider_username - 第三方平台的用户名</li>
 *   <li>created_at - 记录创建时间</li>
 * </ul>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>GitHub 登录 - 用户使用 GitHub 账户登录时创建关联</li>
 *   <li>账户绑定 - 用户绑定多个第三方账户</li>
 *   <li>用户查找 - 根据第三方用户 ID 查找本地用户</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Entity
@Table(name = "oauth_accounts")
public class OAuthAccount {

    /** 主键，UUID 类型，自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 关联用户 ID；OAuth 领域不直接持有用户模块的 JPA 实体。 */
    @Column(name = "user_id", nullable = false)
    private UUID userId;

    /** OAuth 提供者枚举（如 GITHUB、QQ 等） */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OAuthProvider provider;

    /** 第三方平台的用户 ID */
    @Column(name = "provider_user_id", nullable = false, length = 120)
    private String providerUserId;

    /** 第三方平台的用户名 */
    @Column(name = "provider_username", length = 120)
    private String providerUsername;

    /** 记录创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * 默认构造函数，供 JPA 使用
     */
    protected OAuthAccount() {
    }

    /**
     * 构造函数，创建新的 OAuth 账户关联
     *
     * @param userId           关联用户 ID
     * @param provider         OAuth 提供者枚举
     * @param providerUserId   第三方平台的用户 ID
     * @param providerUsername 第三方平台的用户名
     */
    public OAuthAccount(UUID userId, OAuthProvider provider, String providerUserId, String providerUsername) {
        this.userId = userId;
        this.provider = provider;
        this.providerUserId = providerUserId;
        this.providerUsername = providerUsername;
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
     * 获取主键 ID
     *
     * @return UUID 类型的主键
     */
    public UUID getId() {
        return id;
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
     * 获取 OAuth 提供者
     *
     * @return OAuth 提供者枚举
     */
    public OAuthProvider getProvider() {
        return provider;
    }

    /**
     * 获取第三方平台的用户 ID
     *
     * @return 用户 ID 字符串
     */
    public String getProviderUserId() {
        return providerUserId;
    }

    /**
     * 获取第三方平台的用户名
     *
     * @return 用户名字符串
     */
    public String getProviderUsername() {
        return providerUsername;
    }

    /**
     * 获取记录创建时间
     *
     * @return 创建时间
     */
    public Instant getCreatedAt() {
        return createdAt;
    }
}
