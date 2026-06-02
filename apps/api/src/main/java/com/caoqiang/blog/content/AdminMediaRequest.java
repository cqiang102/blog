package com.caoqiang.blog.content;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record AdminMediaRequest(
        UUID contentId,
        MediaAssetType type,
        @NotBlank String publicUrl,
        @Size(max = 240) String filename,
        @Size(max = 120) String contentType,
        Long byteSize,
        Integer width,
        Integer height,
        Integer durationSeconds
) {
}
