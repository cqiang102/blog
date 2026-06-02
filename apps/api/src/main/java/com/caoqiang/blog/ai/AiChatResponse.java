package com.caoqiang.blog.ai;

import java.util.UUID;

public record AiChatResponse(
        UUID sessionId,
        String answer,
        int remainingQuestions,
        int remainingMessages
) {
}
