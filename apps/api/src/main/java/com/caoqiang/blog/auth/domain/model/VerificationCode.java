package com.caoqiang.blog.auth.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 邮箱验证码实体
 * 映射数据库中的 verification_codes 表，存储邮箱验证码及其状态。
 * 位于博客系统的认证模块，用于邮箱验证流程。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>验证码存储 - 存储发送给用户的验证码</li>
 *   <li>过期管理 - 包含过期时间，支持验证码自动失效</li>
 *   <li>使用状态 - 记录验证码是否已被使用，防止重复使用</li>
 *   <li>邮箱关联 - 通过邮箱地址关联到待验证用户</li>
 * </ul>
 *
 * <p>数据库表结构：</p>
 * <ul>
 *   <li>id - 主键，UUID 类型</li>
 *   <li>email - 邮箱地址</li>
 *   <li>code - 验证码</li>
 *   <li>expires_at - 过期时间</li>
 *   <li>used - 是否已使用</li>
 *   <li>created_at - 记录创建时间</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Entity
@Table(name = "verification_codes")
public class VerificationCode {

    /** 主键，UUID 类型，自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 邮箱地址 */
    @Column(nullable = false, length = 255)
    private String email;

    /** 验证码 */
    @Column(nullable = false, length = 10)
    private String code;

    /** 过期时间 */
    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    /** 是否已使用 */
    @Column(nullable = false)
    private boolean used = false;

    /** 记录创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * 默认构造函数，供 JPA 使用
     */
    protected VerificationCode() {}

    /**
     * 构造函数，创建新的验证码
     *
     * @param email     邮箱地址
     * @param code      验证码
     * @param expiresAt 过期时间
     */
    public VerificationCode(String email, String code, Instant expiresAt) {
        this.email = email;
        this.code = code;
        this.expiresAt = expiresAt;
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
     * 获取邮箱地址
     *
     * @return 邮箱地址
     */
    public String getEmail() {
        return email;
    }

    /**
     * 获取验证码
     *
     * @return 验证码
     */
    public String getCode() {
        return code;
    }

    /**
     * 获取过期时间
     *
     * @return 过期时间
     */
    public Instant getExpiresAt() {
        return expiresAt;
    }

    /**
     * 检查验证码是否已使用
     *
     * @return 如果已使用返回 true，否则返回 false
     */
    public boolean isUsed() {
        return used;
    }

    /**
     * 标记验证码为已使用
     */
    public void markUsed() {
        this.used = true;
    }

    /**
     * 检查验证码是否已过期
     *
     * @param now 当前时间
     * @return 如果验证码已过期返回 true，否则返回 false
     */
    public boolean isExpired(Instant now) {
        return !expiresAt.isAfter(now);
    }

    /**
     * 获取创建时间
     *
     * @return 创建时间
     */
    public Instant getCreatedAt() {
        return createdAt;
    }
}
