package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.UUID;

public record AdminMediaResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        MediaAssetType type,
        String bucket,
        String objectKey,
        String publicUrl,
        String filename,
        String contentType,
        Long byteSize,
        Integer width,
        Integer height,
        Integer durationSeconds,
        boolean cover,
        Instant createdAt
) {

    public static AdminMediaResponse from(MediaAsset mediaAsset) {
        Content content = mediaAsset.getContent();
        boolean cover = content != null
                && content.getCoverMedia() != null
                && content.getCoverMedia().getId().equals(mediaAsset.getId());
        return new AdminMediaResponse(
                mediaAsset.getId(),
                content == null ? null : content.getId(),
                content == null ? null : content.getTitle(),
                mediaAsset.getType(),
                mediaAsset.getBucket(),
                mediaAsset.getObjectKey(),
                mediaAsset.getPublicUrl(),
                mediaAsset.getFilename(),
                mediaAsset.getContentType(),
                mediaAsset.getByteSize(),
                mediaAsset.getWidth(),
                mediaAsset.getHeight(),
                mediaAsset.getDurationSeconds(),
                cover,
                mediaAsset.getCreatedAt()
        );
    }
}
