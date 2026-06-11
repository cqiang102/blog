package com.caoqiang.blog.ai.chat.application.dto;

import java.util.List;

/**
 * AI 评论列表查询结果 DTO。
 *
 * @param comments 评论列表
 * @param total    总评论数
 * @param error    错误信息（可选，成功时为 null）
 */
public record AiCommentListResult(
        List<AiCommentItem> comments,
        long total,
        String error
) {

    public static AiCommentListResult success(List<AiCommentItem> comments, long total) {
        return new AiCommentListResult(comments, total, null);
    }

    public static AiCommentListResult error(String error) {
        return new AiCommentListResult(List.of(), 0, error);
    }
}
