package com.caoqiang.blog.content.application.api;

import java.util.UUID;

/** Immutable content data exposed to knowledge indexing and search. */
public record ContentKnowledgeSource(
        UUID id,
        String title,
        String summary,
        String bodyMarkdown
) {
}
