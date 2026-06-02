package com.caoqiang.blog.content;

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

@Entity
@Table(name = "media_assets")
public class MediaAsset {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "content_id")
    private Content content;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MediaAssetType type;

    @Column(nullable = false, length = 120)
    private String bucket;

    @Column(name = "object_key", nullable = false, columnDefinition = "TEXT")
    private String objectKey;

    @Column(name = "public_url", columnDefinition = "TEXT")
    private String publicUrl;

    @Column(length = 240)
    private String filename;

    @Column(name = "content_type", length = 120)
    private String contentType;

    @Column(name = "byte_size")
    private Long byteSize;

    private Integer width;

    private Integer height;

    @Column(name = "duration_seconds")
    private Integer durationSeconds;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected MediaAsset() {
    }

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

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

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

    public void setPublicUrl(String publicUrl) {
        this.publicUrl = publicUrl;
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
