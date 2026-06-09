package com.caoqiang.blog.friend.domain.model;

import com.caoqiang.blog.shared.domain.model.AggregateRoot;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 友链实体
 * <p>
 * 对应数据库 {@code friends} 表，存储友情链接信息。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>存储友链的基本信息（名称、头像、简介、网站 URL）</li>
 *   <li>控制友链的可见性</li>
 *   <li>支持排序权重，用于控制友链展示顺序</li>
 * </ul>
 * <p>
 * 使用 UUID 作为主键，支持创建和更新时间自动维护。
 */
@Entity
@Table(name = "friends")
public class Friend extends AggregateRoot {

    /** 友链名称，最大 80 字符 */
    @Column(nullable = false, length = 80)
    private String name;

    /** 友链头像 URL */
    @Column(name = "avatar_url", columnDefinition = "TEXT")
    private String avatarUrl;

    /** 友链简介 */
    @Column(columnDefinition = "TEXT")
    private String intro;

    /** 友链网站 URL */
    @Column(name = "site_url", nullable = false, columnDefinition = "TEXT")
    private String siteUrl;

    /** 是否可见，默认 true */
    @Column(nullable = false)
    private boolean visible = true;

    /** 排序权重，数值越小越靠前 */
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    /** 创建时间，不可更新 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** 最后更新时间 */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** JPA 保护构造函数 */
    protected Friend() {
    }

    /**
     * 创建友链
     *
     * @param name      友链名称
     * @param avatarUrl 友链头像 URL
     * @param intro     友链简介
     * @param siteUrl   友链网站 URL
     * @param visible   是否可见
     * @param sortOrder 排序权重
     */
    public Friend(String name, String avatarUrl, String intro, String siteUrl, boolean visible, int sortOrder) {
        update(name, avatarUrl, intro, siteUrl, visible, sortOrder);
    }

    /**
     * 实体持久化前的回调，自动设置创建时间和更新时间
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
     * 实体更新前的回调，自动更新更新时间
     */
    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * 更新友链信息
     *
     * @param name      友链名称
     * @param avatarUrl 友链头像 URL
     * @param intro     友链简介
     * @param siteUrl   友链网站 URL
     * @param visible   是否可见
     * @param sortOrder 排序权重
     */
    public void update(String name, String avatarUrl, String intro, String siteUrl, boolean visible, int sortOrder) {
        this.name = name;
        this.avatarUrl = avatarUrl;
        this.intro = intro;
        this.siteUrl = siteUrl;
        this.visible = visible;
        this.sortOrder = sortOrder;
    }

    public String getName() {
        return name;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public String getIntro() {
        return intro;
    }

    public String getSiteUrl() {
        return siteUrl;
    }

    public boolean isVisible() {
        return visible;
    }

    public int getSortOrder() {
        return sortOrder;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
