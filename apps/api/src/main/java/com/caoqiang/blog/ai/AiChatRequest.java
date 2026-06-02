package com.caoqiang.blog.ai;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record AiChatRequest(
        UUID sessionId,
        @NotBlank @Size(max = 2000) String message
) {
}
