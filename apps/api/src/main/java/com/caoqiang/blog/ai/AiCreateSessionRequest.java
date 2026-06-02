package com.caoqiang.blog.ai;

import jakarta.validation.constraints.Size;

public record AiCreateSessionRequest(
        @Size(max = 40) String title
) {
}
