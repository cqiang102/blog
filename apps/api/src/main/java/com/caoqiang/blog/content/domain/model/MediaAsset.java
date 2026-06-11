package com.caoqiang.blog.content.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 媒体资源实体。
 * <p>
 * 对应数据库表 {@code media_assets}，存储博客系统中所有媒体文件的元数据。
 * 支持两种存储模式：
 * <ul>
 *   <li>本地上传：文件存储在 MinIO 中，bucket 和 objectKey 指向实际存储位置</li>
 *   <li>外链引用：文件托管在外部 CDN，bucket 为 "external"，publicUrl 指向外部地址</li>
 * </ul>
 * <p>
 * 关联关系：
 * <ul>
 *   <li>多对一：与 {@link Content} 关联（可为 null，表示独立媒体）</li>
 *   <li>可作为某篇内容的封面媒体（通过 {@link Content#coverMedia} 反向引用）</li>
 * </ul>
 */
@Entity
@Table(name = "media_assets")
public class MediaAsset {

    /** 外链媒体的 bucket 标识，用于区分本地上传和外链引用 */
    public static final String EXTERNAL_BUCKET = "external";

    /** 主键 UUID，创建时自动生成 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 所属内容（可为 null，表示独立媒体资源） */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "content_id")
    private Content content;

    /** 媒体类型：IMAGE / VIDEO / FILE */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MediaAssetType type;

    /** 存储 bucket 名称，外链媒体固定为 "external" */
    @Column(nullable = false, length = 120)
    private String bucket;

    /** MinIO 对象 key，外链媒体为 "external/UUID" */
    @Column(name = "object_key", nullable = false, columnDefinition = "TEXT")
    private String objectKey;

    /** 公开访问 URL，用于前端直接引用 */
    @Column(name = "public_url", columnDefinition = "TEXT")
    private String publicUrl;

    /** 原始文件名 */
    @Column(length = 240)
    private String filename;

    /** MIME 类型，如 image/jpeg、video/mp4 */
    @Column(name = "content_type", length = 120)
    private String contentType;

    /** 文件大小（字节） */
    @Column(name = "byte_size")
    private Long byteSize;

    /** 图片/视频宽度（像素） */
    private Integer width;

    /** 图片/视频高度（像素） */
    private Integer height;

    /** 视频时长（秒） */
    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    /** 创建时间 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** JPA 受保护的无参构造函数 */
    protected MediaAsset() {
    }

    /**
     * 创建媒体资源的构造函数。
     *
     * @param content         所属内容（可为 null）
     * @param type            媒体类型
     * @param bucket          存储 bucket
     * @param objectKey       对象 key
     * @param publicUrl       公开 URL
     * @param filename        文件名
     * @param contentType     MIME 类型
     * @param byteSize        文件大小
     * @param width           宽度
     * @param height          高度
     * @param durationSeconds 视频时长
     */
    public MediaAsset(
            Content content,
            MediaAssetType type,
            String bucket,
            String objectKey,
            String publicUrl,
            String filename,
            String contentType,
            Long byteSize,
            Integer width,
            Integer height,
            Integer durationSeconds
    ) {
        update(content, type, bucket, objectKey, publicUrl, filename, contentType, byteSize, width, height, durationSeconds);
    }

    /** 持久化前自动设置 createdAt */
    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    /**
     * 更新媒体资源属性。
     *
     * @param content         所属内容
     * @param type            媒体类型
     * @param bucket          存储 bucket
     * @param objectKey       对象 key
     * @param publicUrl       公开 URL
     * @param filename        文件名
     * @param contentType     MIME 类型
     * @param byteSize        文件大小
     * @param width           宽度
     * @param height          高度
     * @param durationSeconds 视频时长
     */
    public void update(
            Content content,
            MediaAssetType type,
            String bucket,
            String objectKey,
            String publicUrl,
            String filename,
            String contentType,
            Long byteSize,
            Integer width,
            Integer height,
            Integer durationSeconds
    ) {
        this.content = content;
        this.type = type;
        this.bucket = bucket;
        this.objectKey = objectKey;
        this.publicUrl = publicUrl;
        this.filename = filename;
        this.contentType = contentType;
        this.byteSize = byteSize;
        this.width = width;
        this.height = height;
        this.durationSeconds = durationSeconds;
    }

    /**
     * 设置公开访问 URL。
     *
     * @param publicUrl 公开 URL
     */
    public void setPublicUrl(String publicUrl) {
        this.publicUrl = publicUrl;
    }

    /**
     * 关联或解除关联所属内容。
     *
     * @param content 所属内容，null 表示独立媒体资源
     */
    public void assignTo(Content content) {
        this.content = content;
    }

    public Content getContent() {
        return content;
    }

    public UUID getId() {
        return id;
    }

    public MediaAssetType getType() {
        return type;
    }

    public String getBucket() {
        return bucket;
    }

    public String getObjectKey() {
        return objectKey;
    }

    public String getPublicUrl() {
        return publicUrl;
    }

    public String getFilename() {
        return filename;
    }

    public String getContentType() {
        return contentType;
    }

    public Long getByteSize() {
        return byteSize;
    }

    public Integer getWidth() {
        return width;
    }

    public Integer getHeight() {
        return height;
    }

    public Integer getDurationSeconds() {
        return durationSeconds;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
