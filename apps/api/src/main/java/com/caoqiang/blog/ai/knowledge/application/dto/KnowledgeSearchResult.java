package com.caoqiang.blog.ai.knowledge.application.dto;

/**
 * 知识库搜索结果项 DTO。
 * <p>
 * 用于知识库搜索返回单条结果，替代 {@code Map<String, Object>}。
 *
 * @param content    内容片段
 * @param score      相似度分数
 * @param sourceId   来源 ID
 * @param sourceType 来源类型，区分知识文档和博客内容
 * @param title      来源标题
 * @author caoqiang
 */
public record KnowledgeSearchResult(
        String content,
        double score,
        String sourceId,
        KnowledgeSearchSourceType sourceType,
        String title
) {
}
