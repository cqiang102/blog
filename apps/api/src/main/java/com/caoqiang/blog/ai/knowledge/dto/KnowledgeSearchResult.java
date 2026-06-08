package com.caoqiang.blog.ai.knowledge.dto;

/**
 * 知识库搜索结果项 DTO。
 * <p>
 * 用于知识库搜索返回单条结果，替代 {@code Map<String, Object>}。
 *
 * @param content    内容片段
 * @param score      相似度分数
 * @param contentId  来源内容 ID（字符串形式，可为 null）
 * @param title      来源内容标题（可为 null）
 * @author caoqiang
 */
public record KnowledgeSearchResult(
        String content,
        double score,
        String contentId,
        String title
) {
}
