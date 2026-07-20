package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.MediaReference;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * Reconciles the ordered media references submitted by the content editor with persisted media.
 *
 * <p>The class owns media-reference parsing, ownership checks and external-media lifecycle. Keeping
 * those rules outside {@link ContentAdminService} lets the CRUD service focus on content state and
 * domain events.</p>
 */
@Service
public class ContentMediaSynchronizer {

    private final MediaAssetRepository mediaAssetRepository;

    public ContentMediaSynchronizer(MediaAssetRepository mediaAssetRepository) {
        this.mediaAssetRepository = mediaAssetRepository;
    }

    /**
     * Makes a content item's media collection match the supplied ordered references.
     *
     * @param content content being edited
     * @param references managed media references or external URLs; {@code null} keeps current media
     * @param contentType content type used to infer the type of newly created external media
     * @return the reconciled media list in request order
     */
    public List<MediaAsset> synchronize(Content content, List<String> references, ContentType contentType) {
        if (references == null) {
            return new ArrayList<>(content.getMediaAssets());
        }

        List<MediaAsset> existing = new ArrayList<>(content.getMediaAssets());
        List<MediaAsset> desired = new ArrayList<>();
        Set<UUID> desiredIds = new LinkedHashSet<>();
        Set<String> desiredReferences = new LinkedHashSet<>();
        MediaAssetType fallbackType = contentType == ContentType.VIDEO ? MediaAssetType.VIDEO : MediaAssetType.IMAGE;

        for (String value : references) {
            if (!StringUtils.hasText(value)) {
                continue;
            }
            String reference = value.trim();
            if (!desiredReferences.add(reference)) {
                continue;
            }

            MediaAsset mediaAsset = resolveReference(content, existing, reference, fallbackType);
            Content owner = mediaAsset.getContent();
            if (owner != null && !owner.getId().equals(content.getId())) {
                throw new BusinessException(HttpStatus.CONFLICT, "媒体资源已关联到其他内容");
            }
            if (desiredIds.add(mediaAsset.getId())) {
                mediaAsset.assignTo(content);
                desired.add(mediaAssetRepository.save(mediaAsset));
            }
        }

        detachRemovedMedia(existing, desiredIds);
        content.getMediaAssets().clear();
        content.getMediaAssets().addAll(desired);
        return desired;
    }

    /** Returns the explicitly requested cover, or the first media item when no match exists. */
    public MediaAsset selectCover(List<MediaAsset> mediaAssets, String reference) {
        if (mediaAssets.isEmpty()) {
            return null;
        }
        if (!StringUtils.hasText(reference)) {
            return mediaAssets.getFirst();
        }
        return mediaAssets.stream()
                .filter(media -> matchesReference(media, reference))
                .findFirst()
                .orElse(mediaAssets.getFirst());
    }

    private MediaAsset resolveReference(
            Content content, List<MediaAsset> existing, String reference, MediaAssetType fallbackType) {
        return MediaReference.mediaId(reference)
                .map(id -> mediaAssetRepository
                        .findById(id)
                        .orElseThrow(() -> new BusinessException(HttpStatus.BAD_REQUEST, "引用的媒体资源不存在")))
                .orElseGet(() -> existing.stream()
                        .filter(media -> reference.equals(media.getPublicUrl()))
                        .findFirst()
                        .orElseGet(() -> mediaAssetRepository.save(new MediaAsset(
                                content,
                                fallbackType,
                                MediaAsset.EXTERNAL_BUCKET,
                                MediaAsset.EXTERNAL_BUCKET + "/" + UUID.randomUUID(),
                                reference,
                                null,
                                null,
                                null,
                                null,
                                null,
                                null))));
    }

    private void detachRemovedMedia(List<MediaAsset> existing, Set<UUID> desiredIds) {
        for (MediaAsset mediaAsset : existing) {
            if (desiredIds.contains(mediaAsset.getId())) {
                continue;
            }
            if (MediaAsset.EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
                mediaAssetRepository.delete(mediaAsset);
            } else {
                mediaAsset.assignTo(null);
                mediaAssetRepository.save(mediaAsset);
            }
        }
    }

    private boolean matchesReference(MediaAsset mediaAsset, String reference) {
        return MediaReference.mediaId(reference)
                .map(id -> id.equals(mediaAsset.getId()))
                .orElseGet(() -> reference.equals(mediaAsset.getPublicUrl()));
    }
}
