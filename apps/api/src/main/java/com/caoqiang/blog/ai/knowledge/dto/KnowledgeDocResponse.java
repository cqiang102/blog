package com.caoqiang.blog.ai.knowledge.dto;

import com.caoqiang.blog.ai.knowledge.entity.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.entity.KnowledgeSourceType;
import java.time.Instant;
import java.util.UUID;

public record KnowledgeDocResponse(
        UUID id,
        String title,
        KnowledgeSourceType sourceType,
        String sourceRef,
        String body,
        boolean enabled,
        Instant createdAt,
        Instant updatedAt
) {

    public static KnowledgeDocResponse from(KnowledgeDoc doc) {
        return new KnowledgeDocResponse(
                doc.getId(),
                doc.getTitle(),
                doc.getSourceType(),
                doc.getSourceRef(),
                doc.getBody(),
                doc.isEnabled(),
                doc.getCreatedAt(),
                doc.getUpdatedAt()
        );
    }
}
