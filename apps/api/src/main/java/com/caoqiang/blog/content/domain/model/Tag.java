package com.caoqiang.blog.content.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.UUID;

/**
 * 标签实体。
 * <p>
 * 对应数据库表 {@code tags}，用于对内容进行分类标记。
 * 标签与内容为多对多关系（由 {@link Content} 维护中间表）。
 * <p>
 * slug 字段用于前端 URL 路由和 API 查询参数，全局唯一。
 * <p>
 * 生命周期：通过 {@code @PrePersist} 和 {@code @PreUpdate} 自动维护时间戳。
 */
@Entity
@Table(name = "tags")
public class Tag {

    /** 主键 UUID，创建时自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 标签显示名称 */
    @Column(nullable = false, unique = true, length = 60)
    private String name;

    /** URL 友好的唯一标识符，用于前端路由和查询 */
    @Column(nullable = false, unique = true, length = 80)
    private String slug;

    /** 标签描述（可选） */
    @Column(columnDefinition = "TEXT")
    private String description;

    /** 创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** 最后更新时间 */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** 反向关联：引用该标签的内容集合（由 Content 端维护关系） */
    @ManyToMany(mappedBy = "tags")
    private Set<Content> contents = new LinkedHashSet<>();

    /** JPA 受保护的无参构造函数 */
    protected Tag() {
    }

    /**
     * 创建标签的构造函数。
     *
     * @param name        标签名称
     * @param slug        URL 标识符
     * @param description 标签描述
     */
    public Tag(String name, String slug, String description) {
        this.name = name;
        this.slug = slug;
        this.description = description;
    }

    /** 持久化前自动设置 createdAt 和 updatedAt */
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

    /** 更新前自动刷新 updatedAt */
    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * 更新标签属性。
     *
     * @param name        新名称
     * @param slug        新 slug
     * @param description 新描述
     */
    public void update(String name, String slug, String description) {
        this.name = name;
        this.slug = slug;
        this.description = description;
    }

    public UUID getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getSlug() {
        return slug;
    }

    public String getDescription() {
        return description;
    }
}
