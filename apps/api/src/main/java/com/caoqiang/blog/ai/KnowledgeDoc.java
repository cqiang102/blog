package com.caoqiang.blog.ai;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "knowledge_docs")
public class KnowledgeDoc {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @Column(nullable = false, length = 180)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "source_type", nullable = false, length = 40)
    private KnowledgeSourceType sourceType = KnowledgeSourceType.MANUAL;

    @Column(name = "source_ref", columnDefinition = "TEXT")
    private String sourceRef;

    @Column(columnDefinition = "TEXT")
    private String body;

    @Column(nullable = false)
    private boolean enabled = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected KnowledgeDoc() {
    }

    public KnowledgeDoc(
            String title,
            KnowledgeSourceType sourceType,
            String sourceRef,
            String body,
            boolean enabled
    ) {
        apply(title, sourceType, sourceRef, body, enabled);
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
            KnowledgeSourceType sourceType,
            String sourceRef,
            String body,
            boolean enabled
    ) {
        this.title = title.trim();
        this.sourceType = sourceType;
        this.sourceRef = sourceRef;
        this.body = body;
        this.enabled = enabled;
    }

    public UUID getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public KnowledgeSourceType getSourceType() {
        return sourceType;
    }

    public String getSourceRef() {
        return sourceRef;
    }

    public String getBody() {
        return body;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
