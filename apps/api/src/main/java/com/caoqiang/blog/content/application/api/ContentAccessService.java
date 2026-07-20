package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.application.service.ContentQueryService;
import com.caoqiang.blog.shared.response.PageResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;

/** Public read API for consumers that do not need content-module DTOs. */
@Service
public class ContentAccessService {

    private final ContentQueryService contentQueryService;

    public ContentAccessService(ContentQueryService contentQueryService) {
        this.contentQueryService = contentQueryService;
    }

    public PageResponse<ContentAccessSummary> searchPublished(String query, int limit) {
        var result = contentQueryService.list(query, null, null, null, null, 0, limit);
        return new PageResponse<>(
                result.items().stream()
                        .map(item -> new ContentAccessSummary(
                                item.id(),
                                item.title(),
                                item.summary(),
                                item.type().name()))
                        .toList(),
                result.page(),
                result.size(),
                result.total());
    }

    public ContentAccessDetail publishedDetail(UUID contentId) {
        var detail = contentQueryService.detail(contentId, null);
        return new ContentAccessDetail(
                detail.id(),
                detail.title(),
                detail.summary(),
                detail.bodyMarkdown(),
                detail.type().name(),
                detail.likeCount(),
                detail.viewCount(),
                detail.commentCount());
    }
}
