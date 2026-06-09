package com.caoqiang.blog.ai.chat.application.dto;

/**
 * AI 内容摘要项 DTO。
 * <p>
 * 用于 AI 搜索结果中的内容摘要信息。
 *
 * @param id      内容 ID（字符串形式）
 * @param title   内容标题
 * @param summary 内容摘要
 * @param type    内容类型
 * @author caoqiang
 */
public record AiContentItem(
        String id,
        String title,
        String summary,
        String type
) {
}
