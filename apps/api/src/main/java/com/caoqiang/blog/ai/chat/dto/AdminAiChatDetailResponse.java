package com.caoqiang.blog.ai.chat.dto;

import java.util.List;

public record AdminAiChatDetailResponse(
        AdminAiChatSessionResponse session,
        List<AdminAiChatMessageResponse> messages
) {
}
