package com.caoqiang.blog.ai.chat.application.dto;

import java.util.UUID;

/**
 * AI 聊天响应 DTO。
 *
 * @param sessionId         本次对话所属的会话 ID
 * @param answer            AI 生成的回答文本
 * @param remainingQuestions 今日剩余提问次数
 * @param remainingMessages  当前会话剩余消息数
 */
public record AiChatResponse(
        UUID sessionId,
        String answer,
        int remainingQuestions,
        int remainingMessages
) {
}
