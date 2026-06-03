package com.caoqiang.blog.content;

import java.util.List;

/**
 * 推荐内容响应 DTO。
 * <p>
 * 用于首页推荐模块，包含三组推荐列表：
 * <ul>
 *   <li>{@code pinned} - 置顶内容（按发布时间倒序）</li>
 *   <li>{@code latest} - 最新内容（按发布时间倒序）</li>
 *   <li>{@code mostLiked} - 最热内容（按点赞数倒序）</li>
 * </ul>
 * 每组最多 10 条，结果通过 Redis 缓存。
 */
public record RecommendationResponse(
        /** 置顶内容列表 */
        List<ContentSummaryResponse> pinned,
        /** 最新内容列表 */
        List<ContentSummaryResponse> latest,
        /** 最热内容列表（按点赞数排序） */
        List<ContentSummaryResponse> mostLiked
) {
}
