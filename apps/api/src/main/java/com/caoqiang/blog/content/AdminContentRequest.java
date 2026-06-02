package com.caoqiang.blog.content;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public record AdminContentRequest(
        @NotBlank @Size(max = 180) String title,
        @Size(max = 220) String slug,
        ContentType type,
        ContentStatus status,
        @Size(max = 2000) String summary,
        String bodyMarkdown,
        boolean pinned,
        Instant publishedAt,
        List<String> tagSlugs
) {
}
