package com.caoqiang.blog.content;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TagRequest(
        @NotBlank @Size(max = 60) String name,
        @Size(max = 80) String slug,
        @Size(max = 1000) String description
) {
}
