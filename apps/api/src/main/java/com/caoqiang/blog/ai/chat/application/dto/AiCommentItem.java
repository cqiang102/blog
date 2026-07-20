package com.caoqiang.blog.ai.chat.application.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * AI 评论列表中的单条评论 DTO。
 *
 * @param id        评论 ID
 * @param body      评论内容
 * @param author    作者昵称
 * @param createdAt 创建时间
 */
public record AiCommentItem(UUID id, String body, String author, Instant createdAt) {}
