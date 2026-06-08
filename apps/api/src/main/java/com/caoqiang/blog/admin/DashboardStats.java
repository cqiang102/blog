package com.caoqiang.blog.admin;

/**
 * 管理后台仪表盘统计数据 DTO。
 * <p>
 * 用于返回系统各模块的数据统计，替代 {@code Map<String, Object>}。
 *
 * @param contents      内容总数
 * @param media         媒体资源总数
 * @param friends       友链总数
 * @param users         用户总数
 * @param comments      评论总数
 * @param likes         点赞总数
 * @param views         浏览记录总数
 * @param aiChats       AI 会话总数
 * @param knowledgeDocs 知识库文档总数
 * @author caoqiang
 */
public record DashboardStats(
        long contents,
        long media,
        long friends,
        long users,
        long comments,
        long likes,
        long views,
        long aiChats,
        long knowledgeDocs
) {
}
