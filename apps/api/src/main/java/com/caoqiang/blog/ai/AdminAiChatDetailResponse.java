package com.caoqiang.blog.ai;

import java.util.List;

public record AdminAiChatDetailResponse(
        AdminAiChatSessionResponse session,
        List<AdminAiChatMessageResponse> messages
) {
}
