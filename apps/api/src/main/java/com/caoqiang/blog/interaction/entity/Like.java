package com.caoqiang.blog.interaction.entity;

import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.user.User;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 点赞实体
 * <p>
 * 表示用户对博客内容的点赞记录。位于领域模型层，映射到数据库 likes 表。
 * </p>
 * <p>
 * 关键特性：
 * <ul>
 *   <li>每个用户对同一内容只能点赞一次（通过业务逻辑保证）</li>
 *   <li>自动记录创建时间</li>
 *   <li>与 Content 和 User 实体关联</li>
 * </ul>
 * </p>
 */
@Entity
@Table(name = "likes")
public class Like {

    /** 点赞记录 ID，使用随机 UUID 生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 关联的内容实体 */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "content_id", nullable = false)
    private Content content;

    /** 关联的用户实体（点赞用户） */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** 创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /**
     * JPA 受保护的无参构造函数
     */
    protected Like() {
    }

    /**
     * 创建点赞记录
     *
     * @param content 关联的内容
     * @param user    点赞用户
     */
    public Like(Content content, User user) {
        this.content = content;
        this.user = user;
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

    public Content getContent() {
        return content;
    }

    public UUID getId() {
        return id;
    }

    public User getUser() {
        return user;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
