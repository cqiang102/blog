package com.caoqiang.blog.ai.chat.dto;

import java.util.UUID;

/**
 * AI 操作结果 DTO。
 * <p>
 * 用于 AI 工具方法返回操作结果（点赞、评论等），替代 {@code Map<String, Object>}。
 *
 * @param liked      是否已点赞（点赞/取消点赞操作）
 * @param likeCount  当前点赞数（点赞/取消点赞操作）
 * @param commentId  评论 ID（评论操作）
 * @param body       评论内容（评论操作）
 * @param deleted    是否已删除（删除评论操作）
 * @param error      错误信息（可选，成功时为 null）
 * @author caoqiang
 */
public record AiActionResult(
        Boolean liked,
        Long likeCount,
        String commentId,
        String body,
        Boolean deleted,
        String error
) {

    /**
     * 创建点赞成功结果。
     */
    public static AiActionResult likeSuccess(boolean liked, long likeCount) {
        return new AiActionResult(liked, likeCount, null, null, null, null);
    }

    /**
     * 创建评论成功结果。
     */
    public static AiActionResult commentSuccess(UUID commentId, String body) {
        return new AiActionResult(null, null, commentId.toString(), body, null, null);
    }

    /**
     * 创建删除成功结果。
     */
    public static AiActionResult deleteSuccess() {
        return new AiActionResult(null, null, null, null, true, null);
    }

    /**
     * 创建错误结果。
     */
    public static AiActionResult error(String error) {
        return new AiActionResult(null, null, null, null, null, error);
    }
}
