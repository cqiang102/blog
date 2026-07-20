package com.caoqiang.blog.ai.chat.application.dto;

import jakarta.validation.constraints.Size;

/**
 * 创建 AI 聊天会话请求 DTO。
 *
 * @param title 可选的会话标题（最大 40 字符，为空时默认为"新会话"）
 */
public record AiCreateSessionRequest(@Size(max = 40) String title) {}
