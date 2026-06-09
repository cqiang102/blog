package com.caoqiang.blog.ai.knowledge.application.dto;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeSourceType;
import java.time.Instant;
import java.util.UUID;

/**
 * 知识库文档响应 DTO
 * <p>
 * 用于展示知识库文档的详细信息。
 *
 * @param id         文档 ID
 * @param title      文档标题
 * @param sourceType 来源类型（MANUAL/CONTENT）
 * @param sourceRef  来源引用（内容 ID 或外部链接）
 * @param body       文档内容
 * @param enabled    是否启用
 * @param createdAt  创建时间
 * @param updatedAt  更新时间
 */
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

    /**
     * 从文档实体创建响应 DTO
     *
     * @param doc 知识库文档实体
     * @return 知识库文档响应 DTO
     */
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
