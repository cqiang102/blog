package com.caoqiang.blog.content.application.dto;

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaReference;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 管理端内容响应 DTO。
 * <p>
 * 用于管理端内容列表和详情的响应封装，包含完整的管理所需字段。
 * 相比公开接口的 {@link ContentSummaryResponse}，额外包含 bodyMarkdown、status、计数详情等。
 * <p>
 * 通过静态工厂方法从实体转换，媒体字段使用稳定的同源代理路径。
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
        /** 封面图稳定代理路径 */
        String coverUrl,
        /** 关联媒体资源数量 */
        int mediaCount,
        /** 媒体资源稳定代理路径列表 */
        List<String> mediaUrls,
        /** 点赞数 */
        long likeCount,
        /** 浏览数 */
        long viewCount,
        /** 评论数 */
        long commentCount,
        /** 发布时间 */
        Instant publishedAt,
        /** 逻辑删除时间，null 表示未删除 */
        Instant deletedAt,
        /** 关联标签列表 */
        List<TagResponse> tags) {

    /** 从 Content 实体转换为管理端响应 DTO。 */
    public static AdminContentResponse from(Content content) {
        return new AdminContentResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                MediaReference.normalizeMarkdown(content.getBodyMarkdown(), content.getMediaAssets()),
                content.isPinned(),
                content.getCoverMedia() == null ? null : content.getCoverMedia().getId(),
                content.getCoverMedia() == null
                        ? null
                        : MediaReference.filePath(content.getCoverMedia().getId()),
                content.getMediaAssets().size(),
                content.getMediaAssets().stream()
                        .map(media -> MediaReference.filePath(media.getId()))
                        .toList(),
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount(),
                content.getPublishedAt(),
                content.getDeletedAt(),
                content.getTags().stream().map(TagResponse::from).toList());
    }
}
