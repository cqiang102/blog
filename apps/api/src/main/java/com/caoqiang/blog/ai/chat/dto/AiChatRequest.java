package com.caoqiang.blog.ai.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

/**
 * AI 聊天请求 DTO。
 *
 * @param sessionId 可选的会话 ID，为空时自动复用最近会话或创建新会话
 * @param message   用户消息内容（必填，最大 2000 字符）
 */
public record AiChatRequest(
        UUID sessionId,
        @NotBlank @Size(max = 2000) String message
) {
}
