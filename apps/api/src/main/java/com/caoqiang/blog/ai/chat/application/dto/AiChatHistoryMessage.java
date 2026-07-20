package com.caoqiang.blog.ai.chat.application.dto;

import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;

/** Immutable message history passed from the business store to the model adapter. */
public record AiChatHistoryMessage(AiMessageRole role, String content) {}
