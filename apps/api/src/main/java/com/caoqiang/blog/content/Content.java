package com.caoqiang.blog.content;

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

@Entity
@Table(name = "contents")
public class Content {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @Column(nullable = false, length = 180)
    private String title;

    @Column(nullable = false, unique = true, length = 220)
    private String slug;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ContentType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ContentStatus status = ContentStatus.DRAFT;

    @Column(columnDefinition = "TEXT")
    private String summary;

    @Column(name = "body_markdown", columnDefinition = "TEXT")
    private String bodyMarkdown;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cover_media_id")
    private MediaAsset coverMedia;

    @Column(nullable = false)
    private boolean pinned;

    @Column(name = "like_count", nullable = false)
    private long likeCount;

    @Column(name = "view_count", nullable = false)
    private long viewCount;

    @Column(name = "comment_count", nullable = false)
    private long commentCount;

    @Column(name = "published_at")
    private Instant publishedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @ManyToMany(fetch = FetchType.LAZY)
    @JoinTable(
            name = "content_tags",
            joinColumns = @JoinColumn(name = "content_id"),
            inverseJoinColumns = @JoinColumn(name = "tag_id")
    )
    private Set<Tag> tags = new LinkedHashSet<>();

    @OneToMany(mappedBy = "content", fetch = FetchType.LAZY)
    @OrderBy("createdAt ASC")
    private List<MediaAsset> mediaAssets = new ArrayList<>();

    protected Content() {
    }

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

    public void archive() {
        this.status = ContentStatus.ARCHIVED;
    }

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
