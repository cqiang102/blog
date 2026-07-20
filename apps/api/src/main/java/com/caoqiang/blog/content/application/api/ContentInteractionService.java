package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.application.service.MediaAdminService;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Public content-module API used by interaction workflows. */
@Service
public class ContentInteractionService {

    private final ContentRepository contentRepository;
    private final MediaAdminService mediaAdminService;

    public ContentInteractionService(ContentRepository contentRepository, MediaAdminService mediaAdminService) {
        this.contentRepository = contentRepository;
        this.mediaAdminService = mediaAdminService;
    }

    @Transactional(readOnly = true)
    public Optional<ContentInteractionSnapshot> findPublished(UUID contentId) {
        return contentRepository
                .findByIdAndStatusAndDeletedAtIsNull(contentId, ContentStatus.PUBLISHED)
                .map(this::snapshot);
    }

    @Transactional(readOnly = true)
    public List<ContentInteractionSnapshot> findByIds(Collection<UUID> contentIds) {
        if (contentIds.isEmpty()) {
            return List.of();
        }
        return contentRepository.findAllById(contentIds).stream()
                .map(this::snapshot)
                .toList();
    }

    @Transactional
    public void incrementLikeCount(UUID contentId, long delta) {
        contentRepository.incrementLikeCount(contentId, delta);
    }

    @Transactional
    public void incrementViewCount(UUID contentId, long delta) {
        contentRepository.incrementViewCount(contentId, delta);
    }

    @Transactional
    public void incrementCommentCount(UUID contentId, long delta) {
        contentRepository.incrementCommentCount(contentId, delta);
    }

    public String resolveMediaUrl(String mediaUrl) {
        return mediaAdminService.resolveUrl(mediaUrl);
    }

    private ContentInteractionSnapshot snapshot(Content content) {
        return new ContentInteractionSnapshot(
                content.getId(),
                content.getTitle(),
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount());
    }
}
