package com.caoqiang.blog.ai;

/**
 * AI 获取内容详情结果 DTO。
 * <p>
 * 用于 AI 工具方法返回内容详情，替代 {@code Map<String, Object>}。
 *
 * @param id           内容 ID（字符串形式）
 * @param title        内容标题
 * @param summary      内容摘要
 * @param markdown     Markdown 正文
 * @param type         内容类型
 * @param likeCount    点赞数
 * @param viewCount    浏览数
 * @param commentCount 评论数
 * @param error        错误信息（可选，成功时为 null）
 * @author caoqiang
 */
public record AiContentDetailResult(
        String id,
        String title,
        String summary,
        String markdown,
        String type,
        long likeCount,
        long viewCount,
        long commentCount,
        String error
) {

    /**
     * 创建成功的内容详情结果。
     */
    public static AiContentDetailResult success(
            String id, String title, String summary, String markdown,
            String type, long likeCount, long viewCount, long commentCount
    ) {
        return new AiContentDetailResult(id, title, summary, markdown, type, likeCount, viewCount, commentCount, null);
    }

    /**
     * 创建失败的内容详情结果。
     */
    public static AiContentDetailResult error(String error) {
        return new AiContentDetailResult(null, null, null, null, null, 0, 0, 0, error);
    }
}
