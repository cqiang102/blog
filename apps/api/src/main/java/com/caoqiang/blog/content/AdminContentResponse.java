package com.caoqiang.blog.content;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 管理端内容响应 DTO。
 * <p>
 * 用于管理端内容列表和详情的响应封装，包含完整的管理所需字段。
 * 相比公开接口的 {@link ContentSummaryResponse}，额外包含 bodyMarkdown、status、计数详情等。
 * <p>
 * 通过静态工厂方法 {@link #from(Content)} 从实体转换。
 */
public record AdminContentResponse(
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
        /** Markdown 正文 */
        String bodyMarkdown,
        /** 是否置顶 */
        boolean pinned,
        /** 封面媒体 UUID（可为 null） */
        UUID coverMediaId,
        /** 封面图 URL */
        String coverUrl,
        /** 关联媒体资源数量 */
        int mediaCount,
        /** 媒体资源 URL 列表 */
        List<String> mediaUrls,
        /** 点赞数 */
        long likeCount,
        /** 浏览数 */
        long viewCount,
        /** 评论数 */
        long commentCount,
        /** 发布时间 */
        Instant publishedAt,
        /** 关联标签列表 */
        List<TagResponse> tags
) {

    /**
     * 从 Content 实体转换为管理端响应 DTO。
     *
     * @param content 内容实体
     * @return 管理端内容响应
     */
    public static AdminContentResponse from(Content content) {
        return new AdminContentResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                content.getBodyMarkdown(),
                content.isPinned(),
                content.getCoverMedia() == null ? null : content.getCoverMedia().getId(),
                coverUrl(content),
                content.getMediaAssets().size(),
                content.getMediaAssets().stream()
                        .map(MediaAsset::getPublicUrl)
                        .filter(url -> url != null && !url.isEmpty())
                        .toList(),
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount(),
                content.getPublishedAt(),
                content.getTags().stream().map(TagResponse::from).toList()
        );
    }

    /**
     * 提取封面 URL。
     *
     * @param content 内容实体
     * @return 封面 URL 或 null
     */
    private static String coverUrl(Content content) {
        if (content.getCoverMedia() != null) {
            return content.getCoverMedia().getPublicUrl();
        }
        return null;
    }
}
