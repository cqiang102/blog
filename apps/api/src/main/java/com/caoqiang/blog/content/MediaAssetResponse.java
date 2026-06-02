package com.caoqiang.blog.content;

import java.util.UUID;

public record MediaAssetResponse(
        UUID id,
        MediaAssetType type,
        String publicUrl,
        String filename,
        String contentType,
        Long byteSize,
        Integer width,
        Integer height,
        Integer durationSeconds
) {

    public static MediaAssetResponse from(MediaAsset mediaAsset) {
        return new MediaAssetResponse(
                mediaAsset.getId(),
                mediaAsset.getType(),
                mediaAsset.getPublicUrl(),
                mediaAsset.getFilename(),
                mediaAsset.getContentType(),
                mediaAsset.getByteSize(),
                mediaAsset.getWidth(),
                mediaAsset.getHeight(),
                mediaAsset.getDurationSeconds()
        );
    }
}
