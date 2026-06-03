package com.caoqiang.blog.content;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

/**
 * 管理端内容请求 DTO。
 * <p>
 * 用于管理端创建和更新内容时的请求参数封装。
 * 采用 Java Record 实现，自动提供 getter、equals、hashCode、toString。
 * <p>
 * 验证规则：
 * <ul>
 *   <li>title：必填，最大 180 字符</li>
 *   <li>slug：可选，最大 220 字符（未提供时从 title 自动生成）</li>
 *   <li>type / status：可选（未提供时使用默认值）</li>
 *   <li>summary：可选，最大 2000 字符</li>
 *   <li>tagSlugs：标签 slug 列表，用于关联标签</li>
 * </ul>
 */
public record AdminContentRequest(
        /** 内容标题（必填） */
        @NotBlank @Size(max = 180) String title,
        /** URL 标识符（可选，未提供时从 title 生成） */
        @Size(max = 220) String slug,
        /** 内容类型（可选，默认 ARTICLE） */
        ContentType type,
        /** 内容状态（可选，默认 DRAFT） */
        ContentStatus status,
        /** 内容摘要（可选） */
        @Size(max = 2000) String summary,
        /** Markdown 格式正文 */
        String bodyMarkdown,
        /** 是否置顶 */
        boolean pinned,
        /** 发布时间（可选，发布状态时未指定则默认当前时间） */
        Instant publishedAt,
        /** 关联标签的 slug 列表 */
        List<String> tagSlugs
) {
}
