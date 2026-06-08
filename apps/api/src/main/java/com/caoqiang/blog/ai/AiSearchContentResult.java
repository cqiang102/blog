package com.caoqiang.blog.ai;

import java.util.List;

/**
 * AI 搜索内容结果 DTO。
 * <p>
 * 用于 AI 工具方法返回搜索结果，替代 {@code Map<String, Object>}。
 *
 * @param results 搜索结果列表
 * @param total   符合条件的总数
 * @author caoqiang
 */
public record AiSearchContentResult(
        List<AiContentItem> results,
        long total
) {
}
