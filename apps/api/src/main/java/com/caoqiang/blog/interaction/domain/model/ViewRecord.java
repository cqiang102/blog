package com.caoqiang.blog.interaction.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 浏览记录实体
 * <p>
 * 表示用户对博客内容的浏览记录。位于领域模型层，映射到数据库 view_records 表。
 * </p>
 * <p>
 * 关键特性：
 * <ul>
 *   <li>支持已登录用户和匿名用户的浏览记录</li>
 *   <li>使用 SHA-256 哈希的匿名 ID 进行匿名去重</li>
 *   <li>存储 IP 哈希值（保护用户隐私）</li>
 *   <li>存储 User-Agent 用于设备识别</li>
 *   <li>自动记录创建时间</li>
 * </ul>
 * </p>
 */
@Entity
@Table(name = "view_records")
public class ViewRecord {

    /** 浏览记录 ID，使用随机 UUID 生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 关联的内容 ID */
    @Column(name = "content_id", nullable = false)
    private UUID contentId;

    /** 关联的用户 ID（可为 null，表示匿名用户） */
    @Column(name = "user_id")
    private UUID userId;

    /** 匿名用户 ID（IP + User-Agent 的 SHA-256 哈希） */
    @Column(name = "anonymous_id", length = 120)
    private String anonymousId;

    /** IP 地址的 SHA-256 哈希值 */
    @Column(name = "ip_hash", length = 160)
    private String ipHash;

    /** User-Agent 字符串 */
    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    /** 创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * JPA 受保护的无参构造函数
     */
    protected ViewRecord() {}

    /**
     * 创建浏览记录
     *
     * @param contentId   关联的内容 ID
     * @param userId      关联的用户 ID（可为 null）
     * @param anonymousId 匿名用户 ID
     * @param ipHash      IP 哈希值
     * @param userAgent   User-Agent 字符串
     */
    public ViewRecord(UUID contentId, UUID userId, String anonymousId, String ipHash, String userAgent) {
        this.contentId = contentId;
        this.userId = userId;
        this.anonymousId = anonymousId;
        this.ipHash = ipHash;
        this.userAgent = userAgent;
    }

    /**
     * 持久化前自动设置创建时间
     */
    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getAnonymousId() {
        return anonymousId;
    }

    public String getIpHash() {
        return ipHash;
    }

    public String getUserAgent() {
        return userAgent;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
