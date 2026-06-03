package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 内容详情响应 DTO。
 * <p>
 * 用于公开接口的内容详情展示，包含完整信息：正文 Markdown、媒体资源列表、
 * 当前用户点赞状态等。适用于内容详情页。
 */
public record ContentDetailResponse(
        /** 内容 UUID */
        UUID id,
        /** 标题 */
        String title,
        /** URL 标识符 */
        String slug,
        /** 内容类型 */
        ContentType type,
        /** 内容状态 */
        ContentStatus status,
        /** 摘要 */
        String summary,
        /** Markdown 格式正文 */
        String bodyMarkdown,
        /** 封面图 URL */
        String coverUrl,
        /** 关联标签名称列表 */
        List<String> tags,
        /** 关联媒体资源列表（按创建时间升序） */
        List<MediaAssetResponse> mediaAssets,
        /** 当前登录用户是否已点赞（未登录时为 false） */
        boolean likedByCurrentUser,
        /** 点赞数 */
        long likeCount,
        /** 浏览数 */
        long viewCount,
        /** 评论数 */
        long commentCount,
        /** 发布时间 */
        Instant publishedAt
) {
}
