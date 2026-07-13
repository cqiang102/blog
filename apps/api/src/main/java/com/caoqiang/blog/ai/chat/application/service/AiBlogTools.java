package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiCommentListResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentDetailResult;
import com.caoqiang.blog.ai.chat.application.dto.AiSearchContentResult;

import com.caoqiang.blog.ai.chat.application.dto.AiActionResult;
import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchResult;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeSearchService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import java.util.List;
import java.util.UUID;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

/**
 * Spring AI @Tool 工具类，为 AI 模型提供博客操作能力。
 * <p>
 * 通过 {@code @Tool} 注解声明 8 个工具方法，使 AI 能够：
 * <ul>
 *   <li>搜索和查看博客文章</li>
 *   <li>搜索知识库（向量相似度 + 文本回退）</li>
 *   <li>对文章点赞/取消点赞</li>
 *   <li>对文章发表评论/查询评论/删除评论</li>
 * </ul>
 * 需要用户身份的操作通过 Spring AI 的请求级 {@link ToolContext} 获取当前登录用户。
 */
@Component
public class AiBlogTools {

    public static final String AUTHENTICATED_USER_CONTEXT_KEY = "authenticatedUser";

    private final AiToolService aiToolService;
    private final KnowledgeSearchService knowledgeSearchService;

    public AiBlogTools(
            AiToolService aiToolService,
            KnowledgeSearchService knowledgeSearchService
    ) {
        this.aiToolService = aiToolService;
        this.knowledgeSearchService = knowledgeSearchService;
    }

    /**
     * 搜索博客文章。根据关键词搜索已发布的博客内容，返回匹配的文章列表。
     *
     * @param query 搜索关键词
     * @param limit 返回结果数量上限（最大 10）
     * @return 搜索结果
     */
    @Tool(description = "搜索或浏览已发布的博客内容。用户询问全部、最新、有哪些内容时，query 必须传空字符串；询问特定主题时传关键词。")
    public AiSearchContentResult searchContent(
            @ToolParam(description = "搜索关键词；浏览全部或最新内容时传空字符串", required = false) String query,
            @ToolParam(description = "返回结果数量上限，最大10") int limit
    ) {
        return aiToolService.searchContent(query, limit);
    }

    /**
     * 获取博客文章详情。根据文章 ID 获取完整内容。
     *
     * @param contentId 文章的 UUID
     * @return 内容详情结果
     */
    @Tool(description = "获取博客文章详情。根据文章ID获取完整内容，包括正文、点赞数、浏览数、评论数等。当用户想了解某篇文章的具体内容时调用。")
    public AiContentDetailResult getContentDetail(
            @ToolParam(description = "文章的UUID") UUID contentId
    ) {
        return aiToolService.getContentDetail(contentId);
    }

    /**
     * 搜索或浏览知识库。精确关键词优先，未命中时使用向量相似度搜索。
     *
     * @param query 搜索关键词
     * @return 搜索结果列表
     */
    @Tool(description = "搜索或浏览个人知识库和已发布内容。用户询问知识库有什么、全部来源时，query 必须传空字符串；询问博主、站长、管理员、AI助手、你或具体主题时传简洁关键词。结果的 sourceType=CONTENT 时 sourceId 才能用于 getContentDetail。")
    public List<KnowledgeSearchResult> searchKnowledge(
            @ToolParam(description = "知识关键词；浏览知识库全部来源时传空字符串", required = false) String query
    ) {
        return knowledgeSearchService.search(query);
    }

    /**
     * 对博客文章点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 操作结果
     */
    @Tool(description = "以当前登录用户身份对博客文章点赞。当用户表示喜欢某篇文章或想给文章点赞时调用。")
    public AiActionResult likeContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        return aiToolService.likeContent(currentUser, contentId);
    }

    /**
     * 取消对博客文章的点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 操作结果
     */
    @Tool(description = "以当前登录用户身份取消对博客文章的点赞。当用户想取消之前的点赞时调用。")
    public AiActionResult unlikeContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        return aiToolService.unlikeContent(currentUser, contentId);
    }

    /**
     * 对博客文章发表评论。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @param body      评论内容
     * @return 操作结果
     */
    @Tool(description = "以当前登录用户身份对博客文章发表评论。当用户想对某篇文章发表评论或留言时调用。")
    public AiActionResult commentContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            @ToolParam(description = "评论内容") String body,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        return aiToolService.commentContent(currentUser, contentId, body);
    }

    /**
     * 查询文章的评论列表。返回评论的 ID、内容、作者和时间，可用于后续删除评论操作。
     *
     * @param contentId 文章的 UUID
     * @param limit     返回结果数量上限（最大 20）
     * @return 评论列表
     */
    @Tool(description = "查询文章的评论列表。返回评论的ID、内容、作者和时间信息。当用户想查看某篇文章的评论、查找自己的评论、或需要获取评论ID以便删除评论时调用。")
    public AiCommentListResult listComments(
            @ToolParam(description = "文章的UUID") UUID contentId,
            @ToolParam(description = "返回结果数量上限，最大20") int limit,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        return aiToolService.listComments(
                contentId,
                limit,
                currentUser != null ? currentUser.id() : null
        );
    }

    /**
     * 删除自己的评论。需要用户登录，只能删除自己发布的评论。
     *
     * @param commentId 评论的 UUID
     * @return 操作结果
     */
    @Tool(description = "删除当前登录用户自己的评论。当用户想删除之前发表的评论时调用。只能删除当前登录用户发布的评论。")
    public AiActionResult deleteComment(
            @ToolParam(description = "评论的UUID") UUID commentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        return aiToolService.deleteComment(currentUser, commentId);
    }

    private AuthenticatedUser currentUser(ToolContext toolContext) {
        Object value = toolContext.getContext().get(AUTHENTICATED_USER_CONTEXT_KEY);
        return value instanceof AuthenticatedUser user ? user : null;
    }

}
