package com.caoqiang.blog.content.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * 内容实体。
 * <p>
 * 对应数据库表 {@code contents}，是博客系统的核心业务实体。
 * 支持文章（ARTICLE）、图片（IMAGE）、视频（VIDEO）三种类型。
 * <p>
 * 关联关系：
 * <ul>
 *   <li>多对多：与 {@link Tag} 通过中间表 {@code content_tags} 关联</li>
 *   <li>一对多：与 {@link MediaAsset} 关联（按创建时间升序）</li>
 *   <li>多对一：封面媒体 {@link MediaAsset}（可选）</li>
 * </ul>
 * <p>
 * 生命周期：通过 {@code @PrePersist} 和 {@code @PreUpdate} 自动维护 createdAt / updatedAt 时间戳。
 * <p>
 * 计数字段（likeCount、viewCount、commentCount）通过 {@link ContentRepository} 的原子更新方法维护。
 */
@Entity
@Table(name = "contents")
public class Content {

    /** 主键 UUID，创建时自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 内容标题 */
    @Column(nullable = false, length = 180)
    private String title;

    /** URL 友好的唯一标识符，用于前端路由 */
    @Column(nullable = false, unique = true, length = 220)
    private String slug;

    /** 内容类型：ARTICLE / IMAGE / VIDEO */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ContentType type;

    /** 内容状态：DRAFT / PUBLISHED / ARCHIVED */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ContentStatus status = ContentStatus.DRAFT;

    /** 内容摘要，用于列表展示和 SEO */
    @Column(columnDefinition = "TEXT")
    private String summary;

    /** Markdown 格式的正文内容 */
    @Column(name = "body_markdown", columnDefinition = "TEXT")
    private String bodyMarkdown;

    /** 封面媒体资源（可选），多对一懒加载 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cover_media_id")
    private MediaAsset coverMedia;

    /** 是否置顶 */
    @Column(nullable = false)
    private boolean pinned;

    /** 点赞数，通过原子操作更新 */
    @Column(name = "like_count", nullable = false)
    private long likeCount;

    /** 浏览数，通过原子操作更新 */
    @Column(name = "view_count", nullable = false)
    private long viewCount;

    /** 评论数，通过原子操作更新 */
    @Column(name = "comment_count", nullable = false)
    private long commentCount;

    /** 发布时间，未发布时为 null */
    @Column(name = "published_at")
    private Instant publishedAt;

    /** 创建时间，不可更新 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** 最后更新时间 */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** 关联的标签集合，多对多通过中间表 content_tags */
    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "content_tags",
            joinColumns = @JoinColumn(name = "content_id"),
            inverseJoinColumns = @JoinColumn(name = "tag_id")
    )
    private Set<Tag> tags = new LinkedHashSet<>();

    /** 关联的媒体资源列表，按创建时间升序排列 */
    @OneToMany(mappedBy = "content", fetch = FetchType.LAZY)
    @OrderBy("createdAt ASC")
    private List<MediaAsset> mediaAssets = new ArrayList<>();

    /** JPA 受保护的无参构造函数 */
    protected Content() {
    }

    /**
     * 创建内容的构造函数。
     *
     * @param title        标题
     * @param slug         URL 标识符
     * @param type         内容类型
     * @param status       内容状态
     * @param summary      摘要
     * @param bodyMarkdown Markdown 正文
     * @param pinned       是否置顶
     * @param publishedAt  发布时间
     * @param tags         关联标签集合
     */
    public Content(
            String title,
            String slug,
            ContentType type,
            ContentStatus status,
            String summary,
            String bodyMarkdown,
            boolean pinned,
            Instant publishedAt,
            Set<Tag> tags
    ) {
        apply(title, slug, type, status, summary, bodyMarkdown, pinned, publishedAt, tags);
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
     * 应用内容属性变更。
     * <p>
     * 发布状态时若未指定发布时间则自动设为当前时间。
     * 标签集合采用先清空再添加的方式更新。
     *
     * @param title        标题
     * @param slug         URL 标识符
     * @param type         内容类型
     * @param status       内容状态
     * @param summary      摘要
     * @param bodyMarkdown Markdown 正文
     * @param pinned       是否置顶
     * @param publishedAt  发布时间
     * @param tags         关联标签集合
     */
    public void apply(
            String title,
            String slug,
            ContentType type,
            ContentStatus status,
            String summary,
            String bodyMarkdown,
            boolean pinned,
            Instant publishedAt,
            Set<Tag> tags
    ) {
        this.title = title;
        this.slug = slug;
        this.type = type;
        this.status = status;
        this.summary = summary;
        this.bodyMarkdown = bodyMarkdown;
        this.pinned = pinned;
        this.publishedAt = status == ContentStatus.PUBLISHED
                ? (publishedAt == null ? Instant.now() : publishedAt)
                : publishedAt;
        this.tags.clear();
        this.tags.addAll(tags);
    }

    /**
     * 将内容状态设为归档。
     */
    public void archive() {
        this.status = ContentStatus.ARCHIVED;
    }

    /**
     * 设置封面媒体资源。
     *
     * @param coverMedia 封面媒体实体（可为 null 清除封面）
     */
    public void setCoverMedia(MediaAsset coverMedia) {
        this.coverMedia = coverMedia;
    }

    public UUID getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getSlug() {
        return slug;
    }

    public ContentType getType() {
        return type;
    }

    public ContentStatus getStatus() {
        return status;
    }

    public String getSummary() {
        return summary;
    }

    public String getBodyMarkdown() {
        return bodyMarkdown;
    }

    public MediaAsset getCoverMedia() {
        return coverMedia;
    }

    public boolean isPinned() {
        return pinned;
    }

    public long getLikeCount() {
        return likeCount;
    }

    public long getViewCount() {
        return viewCount;
    }

    public long getCommentCount() {
        return commentCount;
    }

    public Instant getPublishedAt() {
        return publishedAt;
    }

    public Set<Tag> getTags() {
        return tags;
    }

    public List<MediaAsset> getMediaAssets() {
        return mediaAssets;
    }
}
