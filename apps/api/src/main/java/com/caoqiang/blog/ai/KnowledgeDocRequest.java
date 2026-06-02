package com.caoqiang.blog.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record KnowledgeDocRequest(
        @NotBlank @Size(max = 180) String title,
        @NotNull KnowledgeSourceType sourceType,
        String sourceRef,
        String body,
        @NotNull Boolean enabled
) {
}
