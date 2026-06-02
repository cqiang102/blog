package com.caoqiang.blog.ai;

import java.util.List;
import java.util.UUID;

public record AiChatResponse(
        UUID sessionId,
        String answer,
        List<ToolSuggestion> suggestedTools,
        int remainingQuestions
) {
}
