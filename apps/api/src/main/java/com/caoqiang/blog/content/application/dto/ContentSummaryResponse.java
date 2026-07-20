package com.caoqiang.blog.content.application.dto;

import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import java.io.Serializable;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * 内容摘要响应 DTO。
 * <p>
 * 用于公开接口的内容列表展示，仅包含摘要级别信息，不包含正文 Markdown。
 * 适用于内容列表页、推荐列表、搜索结果等场景。
 */
public record ContentSummaryResponse(
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
        /** 封面图 URL */
        String coverUrl,
        /** 是否置顶 */
        boolean pinned,
        /** 点赞数 */
        long likeCount,
        /** 发布时间 */
        Instant publishedAt,
        /** 关联标签名称列表 */
        List<String> tags)
        implements Serializable {}
