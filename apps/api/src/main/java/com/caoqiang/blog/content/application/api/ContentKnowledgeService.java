package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.application.service.ContentQueryService;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Public content-module API used by AI knowledge workflows. */
@Service
public class ContentKnowledgeService {

    private final ContentRepository contentRepository;
    private final ContentQueryService contentQueryService;

    public ContentKnowledgeService(
            ContentRepository contentRepository,
            ContentQueryService contentQueryService
    ) {
        this.contentRepository = contentRepository;
        this.contentQueryService = contentQueryService;
    }

    @Transactional(readOnly = true)
    public Optional<ContentKnowledgeSource> findIndexable(UUID contentId) {
        return contentRepository.findByIdAndStatusAndDeletedAtIsNull(contentId, ContentStatus.PUBLISHED)
                .map(this::source);
    }

    @Transactional(readOnly = true)
    public List<ContentKnowledgeSource> findPublishedByIds(Collection<UUID> contentIds) {
        if (contentIds.isEmpty()) {
            return List.of();
        }
        return contentRepository.findByIdInAndStatusAndDeletedAtIsNull(
                List.copyOf(contentIds),
                ContentStatus.PUBLISHED
        ).stream().map(this::source).toList();
    }

    @Transactional(readOnly = true)
    public List<ContentKnowledgeSource> searchPublished(String query, int limit) {
        return contentQueryService.list(query, null, null, null, null, 0, limit)
                .items().stream()
                .map(item -> new ContentKnowledgeSource(
                        item.id(),
                        item.title(),
                        item.summary(),
                        null
                ))
                .toList();
    }

    private ContentKnowledgeSource source(Content content) {
        return new ContentKnowledgeSource(
                content.getId(),
                content.getTitle(),
                content.getSummary(),
                content.getBodyMarkdown()
        );
    }
}
